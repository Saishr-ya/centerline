% --------------------------------
% GEOMETRIC CENTERLINE EXTRACTION
% --------------------------------

ptCloud = pcread('volumefixclean1.ply'); 

ptCloud_locations = ptCloud.Location;

%PCA finds the most important axis 
[coeff, ~, ~] = pca(ptCloud_locations);
primary_axis = coeff(:, 1);

fprintf('Primary axis direction vector: [%.4f, %.4f, %.4f]\n', primary_axis(1), primary_axis(2), primary_axis(3));

% --- Step 2: Define slicing planes ---
projected_points_all = ptCloud_locations * primary_axis;
start_point = min(projected_points_all);
end_point = max(projected_points_all);

num_slices = 50;
slice_locations = linspace(start_point, end_point, num_slices);

slice_interval = (end_point - start_point) / (num_slices - 1);
slice_thickness = slice_interval * 1.5;

fprintf('Slicing along primary axis from %.2f to %.2f with %d slices.\n', start_point, end_point, num_slices);
fprintf('Calculated slice thickness: %.2f units\n', slice_thickness);

centerline_points = zeros(num_slices, 3);

for k = 1:num_slices
    current_slice_loc = slice_locations(k);
    slice_indices = find(abs(projected_points_all - current_slice_loc) < slice_thickness / 2);

    if ~isempty(slice_indices)
        slice_points = ptCloud_locations(slice_indices, :);
        centroid = mean(slice_points, 1);
        centerline_points(k, :) = centroid;
    else
        fprintf('Warning: Slice %d is empty. Skipping this slice.\n', k);
    end
end

centerline_points = centerline_points(any(centerline_points, 2), :);

fprintf('Centerline extraction complete. Found %d points.\n', size(centerline_points, 1));

% -------------------------------------------------------------------------
% 2. VISUALIZATION: PLOTTING THE CENTERLINE ON THE POINT CLOUD
% -------------------------------------------------------------------------

% Explicitly create a figure and get a handle to its axes
h_fig = figure('Name', 'Point Cloud with Centerline Overlay');
h_ax = axes('Parent', h_fig);
hold(h_ax, 'on');

title(h_ax, 'Point Cloud with Centerline Overlay');
xlabel(h_ax, 'X');
ylabel(h_ax, 'Y');
zlabel(h_ax, 'Z');
grid(h_ax, 'on');
axis(h_ax, 'equal');

% --- Set a uniform color for the point cloud before plotting ---
% Creating white matrix 
white = uint8([255, 255, 255]); 
ptCloud.Color = repmat(white, ptCloud.Count, 1);

% --- Display the Point Cloud ---
% Now pcshow will use the color stored in the ptCloud object
pcshow(ptCloud, 'Parent', h_ax, 'MarkerSize', 10);
view(h_ax, 3);

% --- Overlay the Extracted Centerline ---
if ~isempty(centerline_points)
    plot3(h_ax, centerline_points(:, 1), centerline_points(:, 2), centerline_points(:, 3), ...
          'r-', 'LineWidth', 4);
    plot3(h_ax, centerline_points(:, 1), centerline_points(:, 2), centerline_points(:, 3), ...
          'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 5);
    fprintf('Centerline plotted successfully.\n');
else
    fprintf('No centerline points to plot.\n');
end

%---Calculate volume of 3D Scan ---
shape = alphaShape(double(ptCloud_locations));
V = volume(shape);

hold(h_ax, 'off');
fprintf('--- Visualization Complete ---\n');

fprintf('Volume calculated by alphaShape: %.4f cubic units\n', V);

vol_in3 = V / 16387.064;

vol_actual = 300; 

accuracy_threshold = 85; % The desired accuracy threshold to stop at

initial_measured_volume = vol_in3;

initial_points = ptCloud.Count;

error_percentage = (abs(initial_measured_volume - vol_actual) / vol_actual) * 100;
initial_accuracy = 100 - error_percentage;

fprintf('Starting with an initial accuracy of %.2f%% from a measured volume of %.4f in^3.\n\n', ...
    initial_accuracy, initial_measured_volume);

% Initialize loop variables
accuracy = initial_accuracy; % Start the loop with the initial accuracy
iteration = 0;
removal_percentage = 0.05; % Remove 5% of points in each iteration

while accuracy >= accuracy_threshold
    iteration = iteration + 1;
    current_num_points = size(ptCloud_locations, 1);
    
    % Randomly remove a percentage of points
    num_to_remove = round(current_num_points * removal_percentage);
    if current_num_points - num_to_remove < 100
        fprintf('Warning: Too few points remaining. Breaking loop.\n');
        break;
    end
    
    % Get indices to keep (remove the rest)
    indices_to_keep = randperm(current_num_points, current_num_points - num_to_remove);
    ptCloud_locations = ptCloud_locations(indices_to_keep, :);
    
    % --- Calculate volume of the current point cloud ---
    shape = alphaShape(double(ptCloud_locations));
    V = volume(shape);
    vol_in3 = V / 16387.064;
    
    % --- Calculate and display accuracy ---
    error_percentage = (abs(vol_in3 - vol_actual) / vol_actual) * 100;
    accuracy = 100 - error_percentage;
    
    fprintf('Iteration %d: Points = %d, Volume = %.4f in^3, Accuracy = %.2f%%\n', ...
        iteration, size(ptCloud_locations, 1), vol_in3, accuracy);
end

% --- Final Output ---
fprintf('\n--- Iteration Complete ---\n');
points_removed = initial_points - size(ptCloud_locations, 1);

fprintf('Process stopped because accuracy dropped below %.2f%%.\n', accuracy_threshold);
fprintf('Final Volume Calculated: %.4f in^3\n', vol_in3);
fprintf('Final Accuracy: %.2f%%\n', accuracy);
fprintf('Total points remaining: %d\n', size(ptCloud_locations, 1));
fprintf('Total pixels (points) removed: %d\n', points_removed);
