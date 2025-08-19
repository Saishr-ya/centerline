% --------------------------------
% GEOMETRIC CENTERLINE EXTRACTION
% --------------------------------

ptCloud = pcread('balloonclean.ply'); 

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
