import numpy as np
from stl import mesh
import cv2
import matplotlib.pyplot as plt


def stl_to_2d_sketches(
    stl_path,
    output_prefix,
    line_thickness=1,
    text_scale=1.5,
    slide_interval=None,
    edge_angle_threshold=60,
):
    # Read the STL file
    mesh_data = mesh.Mesh.from_file(stl_path)

    # Define projection planes
    planes = [
        ("front", [0, 1, 2], [0, 0, 1]),  # XY plane (front view)
        ("back", [0, 1, 2], [0, 0, -1]),  # XY plane (back view)
        ("left", [2, 1, 0], [-1, 0, 0]),  # ZY plane (left side view)
        ("right", [2, 1, 0], [1, 0, 0]),  # ZY plane (right side view)
        ("top", [0, 2, 1], [0, 1, 0]),  # XZ plane (top view)
        ("bottom", [0, 2, 1], [0, -1, 0]),  # XZ plane (bottom view)
    ]

    for plane_name, axes, view_vector in planes:
        # Get the range for sliding
        z_min, z_max = (
            mesh_data.vectors[:, :, axes[2]].min(),
            mesh_data.vectors[:, :, axes[2]].max(),
        )

        if slide_interval is None:
            z_positions = [(z_min + z_max) / 2]  # Use middle position for single view
        else:
            z_positions = np.arange(z_min, z_max, slide_interval)

        for slide_index, z_pos in enumerate(z_positions):
            # Project vertices onto the plane
            points = mesh_data.vectors[:, :, axes]
            projected_points = points[:, :, :2]

            # Create high-resolution images
            img_size = 2000
            img = np.zeros((img_size, img_size), dtype=np.uint8)
            img_with_measurements = np.zeros((img_size, img_size, 3), dtype=np.uint8)

            # Normalize points to fit in the image
            min_vals = projected_points.min(axis=(0, 1))
            max_vals = projected_points.max(axis=(0, 1))
            scale = (img_size - 200) / (
                max_vals - min_vals
            ).max()  # Leave more margin for measurements
            normalized_points = (projected_points - min_vals) * scale
            normalized_points += 100  # Add margin

            # Calculate face normals
            v0 = mesh_data.vectors[:, 0, :]
            v1 = mesh_data.vectors[:, 1, :]
            v2 = mesh_data.vectors[:, 2, :]
            normals = np.cross(v1 - v0, v2 - v0)
            normals /= np.linalg.norm(normals, axis=1)[:, np.newaxis]

            # make sure the normals are pointing towards the camera
            view_vector = np.array(view_vector)

            # remove any negative values
            normals = np.abs(normals)

            # ensure we only capture the face
            normals = np.where(normals > 0, normals, 0)

            # Identify edges to draw
            dot_products = np.dot(normals, view_vector)
            visible_faces = dot_products < np.cos(np.radians(edge_angle_threshold))

            # Draw visible edges
            for i, is_visible in enumerate(visible_faces):
                if is_visible:
                    pts = normalized_points[i].astype(np.int32)
                    cv2.polylines(img, [pts], True, 255, line_thickness, cv2.LINE_AA)
                    cv2.polylines(
                        img_with_measurements,
                        [pts],
                        True,
                        (255, 255, 255),
                        line_thickness,
                        cv2.LINE_AA,
                    )

            # Add measurements
            real_dimensions = max_vals - min_vals

            # add 100px margin to the right
            img_with_measurements = cv2.copyMakeBorder(
                img_with_measurements,
                0,
                0,
                0,
                100,
                cv2.BORDER_CONSTANT,
                value=(0, 0, 0),
            )

            # Bottom measurement
            cv2.line(
                img_with_measurements,
                (100, img_size - 60),
                (img_size - 100, img_size - 60),
                (0, 255, 0),
                2,
            )
            cv2.putText(
                img_with_measurements,
                f"{real_dimensions[0]:.2f}mm",
                (img_size // 2, img_size - 20),
                cv2.FONT_HERSHEY_SIMPLEX,
                text_scale,
                (0, 255, 0),
                1,
            )

            # Right side measurement
            cv2.line(
                img_with_measurements,
                (img_size - 80, 100),
                (img_size - 80, img_size - 100),
                (0, 255, 0),
                2,
            )
            cv2.putText(
                img_with_measurements,
                f"{real_dimensions[1]:.2f}mm",
                (img_size - 150, img_size // 2),
                cv2.FONT_HERSHEY_SIMPLEX,
                text_scale,
                (0, 255, 0),
                1,
                cv2.LINE_AA,
                True,
            )

            # Add view information
            view_info = f"View: {plane_name.capitalize()}"
            if slide_interval is not None:
                view_info += f", Slice: {z_pos:.2f} mm"
            cv2.putText(
                img_with_measurements,
                view_info,
                (50, 50),
                cv2.FONT_HERSHEY_SIMPLEX,
                text_scale,
                (0, 255, 0),
                2,
            )

            # Save the sketches
            slice_suffix = (
                f"_slice_{slide_index:03d}" if slide_interval is not None else ""
            )
            cv2.imwrite(
                f"{output_prefix}_{plane_name}{slice_suffix}.png",
                img_with_measurements,
            )

            print(
                f"Saved {plane_name} view{slice_suffix} with measurements to {output_prefix}_{plane_name}{slice_suffix}.png"
            )

    print("All sketches generated successfully.")


# Usage
stl_to_2d_sketches(
    "input.stl",
    "output_sketch",
    line_thickness=1,
    text_scale=1.5,
    slide_interval=None,
    edge_angle_threshold=60,
)
