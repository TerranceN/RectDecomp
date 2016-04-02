RectDecomp
==========

The purpose of this project is to take in a `.obj` file and output a set of rectangles that approximate the space.

The first step is voxelizing the object, then using the voxelization and some other precomputed things, generate a set of rectangles that fill the voxelization.

The input mesh has two requirements:

- It has no holes.

- The faces are all triangles.

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

`M` -> toggle view modes (currently just the model and voxels)

`C` -> toggle whether to color each rendered item a different color

`H` -> toggle whether to only draw half of the items that could be rendered (useful to 'see inside' the voxelization)

`click and drag` -> rotate the camera

Command line switches
---------------------

The command line switches are formatted like `--switch:argument`:

`--out` - outputs the list of rects in the given file as text. One on each line, with the x, y, and z, of the lower corner, followed by the size

`--view` - optinally takes an argument that's either 'model', or 'voxels' for the viewer's default view

`--voxelSize` - takes a float parameter that's the voxels size used to voxelize the model

Example:
```bash
# voxelizes monkey.obj with a voxel size of 0.01 units, and opens a viewer with the voxel view selected
./main --voxelSize:0.01 --view:voxels assets/monkey.obj
```
