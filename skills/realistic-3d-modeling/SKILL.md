---
name: realistic-3d-modeling
license: MIT
description: Build and refine photorealistic, orbitable 3D assets from references. Use for procedural modeling, standalone GLB and offline viewer delivery, or diagnosing realism failures through render-and-review iterations.
---

# Realistic 3D modeling

When matching an external quality benchmark, compare assets on the same subject, scale, views, lighting and detail budget. A convincing hero image alone establishes little about the back, underside or reusable mesh.

## Compare design pitches

- Give each participating model the same starter mesh, scene units, named 3D landmarks, and camera views. Save each camera's pose, projection, framing, and output resolution so Blender can reproduce the view. Supply clean renders and copies with projected landmarks.
- Have each model pitch its own design with images from those cameras. Ask it to identify any intended changes to the starter geometry. Compare corresponding views side by side and save the winning images and accepted changes as the build reference.
- Verify the winning design in Blender. Render the finished mesh through the saved cameras and overlay its silhouettes and landmarks on the pitch images. Inspect another angle for shapes or intersections hidden in the pitch.
- Render the same view with a broad studio light, then with a grazing light. Keep the camera, materials, and exposure fixed. Check the surface relief and how highlights move across materials, then record any mismatch for the review loop.

## Build the asset

1. Establish the intended viewing distance and one physical dimension. Gather a whole-subject photograph, a structural side view and a close-up that answers a specific material or attachment question. Record source, author, license and adaptations for embedded assets. If the request is research only, return findings before building.
2. Model from the silhouette inward. Check proportions and negative space in two views. Then inspect contact points, joints, overlaps and thin parts in grazing light. Apply variation at the scale where it occurs in the subject. Seed procedural choices separately so changing a petal or garnish preserves the overall arrangement during comparison.
3. Establish material appearance under a known light. Wet, oily, translucent and rough surfaces should respond differently as the camera moves. Use a shared neutral light when diagnosing defects and the intended environment for final judgment. Read the [subject notes](references/subject-notes.md) for worked botanical and culinary examples.
4. For dependency-free delivery, use local mesh generation, embedded textures and an offline orbit viewer. Keep the exported GLB usable independently. Reuse geometry for repeated objects and budget texture detail by projected size. An efficient interactive renderer and a full-quality still can share the same model.

## Match the orbit to a Blender still

- When the lighting is fixed and complex materials lose their appearance during orbit, capture the finished Cycles scene from a set of known cameras for each light. Keep the original full-resolution still at its exact camera. Project nearby captures onto the same mesh, using each source camera’s depth to reject hidden surfaces. Load nearby views on demand and bound the decoded texture cache.
- If a silhouette leaves a ghost on the ground during a drag, render the ground separately under each light. Hide the subject from camera rays while keeping its cast shadow. Map this pass onto the ground in world coordinates. Where glossy highlights drift between views, add capture angles around the affected view and measure the improvement.
- Verify the actual interactive frame while the pointer is held. First drag away and back to the reference camera. Then compare an intermediate drag pose with an independent Cycles render from that exact pose, held out of the capture set. Match the projection, light, exposure and pixel dimensions for each comparison. Under each light, check mean absolute RGB error across the frame and in a crop around the reflective material. Inspect the images side by side for ghost edges and highlight motion that a whole-frame average can hide.

## Run the visual review loop

- Freeze each candidate before review. Save the geometry or its hash, renderer settings and immutable stills. Start with the hero view, a substantially different orbit angle and one targeted detail. Label neutral studio renders, crops and real reference photos accurately. Verify that the alternate angle actually changed.
- When a panel is requested, render the evidence once and give each reviewer the same labeled views. Collect independent feedback before sharing the panel’s findings. Record which reviewer assessed which candidate and whether actionable feedback remains. Use only reviewers and sharing channels authorized for the material.
- Ask: **“Where in the image does it stop looking photographic? What do you see, what cause do you suspect, and what change or test would distinguish that cause? Does actionable feedback remain?”** Preserve disagreements. A reviewer who sees no root or menma may have found a visibility problem even when that geometry exists.
- Rank findings by visible impact. Correct impossible geometry and broken contact first. For a recurring criticism, change the investigation: isolate geometry with a clay render, then compare color-only, normal-only and fully shaded views. Inspect UV ownership, a cross section or collision distances where appropriate. Return to a specific real reference if the build still disagrees with it.
- Rerender the same views from the changed asset. Verify each claimed fix in the image and with a geometric check when possible. Give all requested reviewers the new candidate. A successful file check, silence, a missing verdict and an approval of an older image do not count as visual sign-off. When unanimity is requested, completion requires every named reviewer to clear the same candidate. Honor a user's pause immediately and retain the latest verified state.

## Protect the workstation

Estimate **decoded working memory** before increasing resolution. For an RGBA8 texture with a full mip chain, budget roughly `width × height × 4 × 4/3` bytes per map. Add decoded source images, geometry, browser copies, depth and color targets, and simultaneous processes. Use the decoded total to size the cache and choose an atlas resolution.

Measure peak memory with a representative render on the target device. If concurrent jobs exceed the available memory, run geometry export, full-quality rendering and independent verification sequentially. Reuse one task-owned preview, release workers and graphics resources when hidden or finished, and share saved stills. If pressure rises or the renderer disconnects, stop the heavy job, preserve the last working output, reduce the allocation that caused the spike, and verify recovery before retrying.

## Verify and hand off

Open or exercise the delivered viewer offline. Confirm orbit and detail views display different geometry projections, verify the still corresponds to the published candidate, and inspect the GLB independently for geometry, materials, texture references and bounds. Check the embedded GLB against the standalone file when the viewer embeds one. Report functional verification and visual verdicts separately. At a pause, retain the candidate identifier, exact reviewer coverage, largest unresolved defect and next discriminating test so the next session can incorporate the user's input.
