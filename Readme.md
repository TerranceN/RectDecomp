RectDecomp
==========

The purpose of this project is to take in a `.obj` file and output a set of rectangles that approximate the space.

The first step is voxelizing the object (which is technically sufficient for the above result, but really inefficient output to process). This is all that's currently done.

Building and Running
--------------------

Assuming you have a recent version of nim and nimble installed, you should be able to simply:

```bash
cd the/project/directory
nimble update
nimble install
```

And have a working program. Lmk if that doesn't work for you.

Viewer
------

This also includes a model viewer. It's currently configured to be at the right distance from the origin to view the monkey.obj file in the assets folder. I will make this more dynamic if needed.

M -> toggle view modes (currently just the model and voxels)

Command line switches
---------------------

There are currently two command line switches:

--view - optinally takes an argument that's either 'model', or 'voxels' for the viewer's default view
--voxelSize - takes a float parameter that's the voxels size used to voxelize the model

Example:
```bash
# voxelizes monkey.obj with a voxel size of 0.01 units, and opens a viewer with the voxel view selected
./main --voxelSize:0.01 --view:voxels assets/monkey.obj
```
