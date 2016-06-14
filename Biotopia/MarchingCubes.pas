//----------------------------------------------------------------------------
// Geoblock is a program for modeling and visualization of geoscience datasets.
//
// The contents of this file are subject to the Mozilla Public License
// Version 1.1 (the "License"); you may not use this file except in compliance
// with the License. You may obtain a copy of the License at http://www.mozilla.org/MPL/
//
// Software distributed under the License is distributed on an "AS IS" basis,
// WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
// the specific language governing rights and limitations under the License.
//
//---------------------------------------------------------------------------
{-------------------------------------------------------------------------------
 Initial developer:  Aaron Hochwimmer.
 Heavily Based on code from
 http://www.delphi3d.net/articles/viewarticle.php?article=metaballs.htm

 There are 256 possible ways for the surface to intersect a cube. The
 EDGETABLE is used to look up edges that are intersected by the metaball,
 starting from the vertices between which the surface is known to pass.
 When edges are known to intersect the surface, TRITABLE is used to form
 triangles from the intersection points.

  These tables were taken from Paul Bourke's site:
    http://www.swin.edu.au/astronomy/pbourke/modelling/

The modified versions of the algorithm:

http://astronomy.swin.edu.au/~pbourke/modelling/polygonise/
(has some info on normals)

http://www.wheatchex.com/projects/viz2001/01_mcubes/

http://graphics.lcs.mit.edu/classes/6.838/S98/meetings/m7/voxels.html
(talks about 8 different cases for solving the "holes" problem)

There is a variant called the "Dividing Cubes Algorithm" which
claims to solve the ambiguity. From
http://www.kev.pulo.com.au/sv3/sv3_1999_assignment1/node15.html

"However, by far the largest problem with the Marching Cubes algorithm
is that of ambiguity in the surface. This occurs when the wrong decision
is made about whether a vertex is contained by the surface (such as when
the assumption of one edge-surface intersection per voxel edge breaks
down), or if the triangles chosen at adjacent voxels don't fit together
properly. The result is a hole in the constructed surface, usually of
the order of a voxel's face. One such example is illustrated in [2],
which also refers to a similar algorithm by Wyvill et al in [2,
References 2,3,4], which correctly handles these cases. In addition,
Dividing Cubes [5, Reference 2], Marching Tetrahedra [5, Reference 14]
and Asymptotic Decider [3], are all algorithms based on Marching Cubes
which attempt to solve this problem."

Perhaps we should modify the code to one of these variants? This might
also get around any patent issues with the original version.

That's a good idea to optimise for space. I basically just went from the
metaball code that I found on Delphi3d.net. In most cases for marching
cubes you probably would know the data ahead of time as such: regular
measured data or simulation results.

I think the polygoniser algorithm
http://www.unchainedgeometry.com/jbloom/papers/polygonizer.pdf
looks better for points evaluated by function (using SCEvaluator) simply
because you can evaluate the function anywhere, rather than be
restricted to the cube vertices.

Also that algorithm doesn't have any patent issues.

Feel free to modify it as you see fit. As you say it would be good to
have a (cleaned up) version in GLScene.

Some surfaces it just didn't work on unfortunately. I tried the
algorithm on this one
http://astronomy.swin.edu.au/~pbourke/surfaces/heart2/
(thinking I could make a move on the lucrative Valentine's Day card
market :)) but it had problems. I think its because marching cubes has
ambiguities in some instances.

> The question is regarding the vertex normals.. Have you given that
> much thought? For a fast method of weighed triangle normal averages
> at a vertex, the only method that I can think of is pretty ugly (it
> involves storing created vertex indices in a sparse array of dim
> ~ x * y * N..) I  might need to read up on the literature for that.


If one has an implicit surface equation, vertex normals can be calculated
from the gradients at the vertices (it just means 3 additional function
calls for each vertex, actually I might implement this in my function
plotter, FormEx3D). However, when all one has is the node data, a
calculation probably needs to be done using triangle normals, which could be
speeded up quite a bit by indexing the vertices from the previous slab as
one moves along.

Rather than use a DirectGL object it should probably be rendered by a GLFreeForm/GLMeshObject(s).
Another bonus would be that the mesh can later be stripified.

For measured datasets it might be useful to handle a list of meshes for
different isosurfaces (e.g. temperature isosurfacs at 50 degree intervals.

It certainly is more efficient to do this at the component
level when each data point needs to be calculated and is not stored.
Otherwise, however, there's not a big advantage over multiple
invocations or multiple components.

If possible the unit needs to be made more modular. In a way it makes
sense to make a TMarchingCubes component because then we can implement
an event handler "OnCalculate"? to do the call to evaluate the function
F(x,y,z) either from a known function or from a dataset array of some
kind.

For speed considerations, there should be both a floating point and
an integer argument version. Also, calculating normals
can be affected (optionally) if you are plotting an implicit function (that
is one that's continuous) or discrete data (although one way to calculate
normals for discrete data is to take differences instead of derivatives,
which would work better for non-quantized data)

Overtime such a component could be extended to provide the marching cube
variant algorithms such as marching tetrahedra or dividing cubes.

It seems that there is another bug in the following segment, 1's should actually be
0's:

  if (abs(1-valp1) < DSMALL) then
  begin
    result := p1;
    exit;
  end;
  if (abs(1-valp2) < DSMALL) then
  begin
    result := p2;
    exit;
  end;

Also, only the function value at the grid, and not it's coordinates need to
be stored in the GRID array.

One benefit of volumetric data is the ease of implementing CSG. This can be
implemented at the data level or at the component level.

I'm also considering some sort of optimization for real time local
modifications (ie CSG with "small" objects). That would come in handy for
things like 4 axis mill simulators (OK, I have a vested interest in this
one).

Something needs to be done about the normals.
Been thinking about it some more. Rather than use a DirectGL object it
should probably be rendered by a GLFreeForm/GLMeshObject(s).

For measured datasets it might be useful to handle a list of meshes for
different isosurfaces (e.g. temperature isosurfacs at 50 degree intervals).

If possible the unit needs to be made more modular. In a way it makes
sense to make a TMarchingCubes component because then we can implement
an event handler "OnCalculate"? to do the call to evaluate the function
F(x,y,z) either from a known function or from a dataset array of some kind.

Overtime such a component could be extended to provide the marching cube
variant algorithms such as marching tetrahedra or dividing cubes.

-------------------------------------------------------------------------------}


unit MarchingCubes;

interface

uses
  GLCommon, GLS.Vectors;

type
  TConstraints = record
    xmin, xmax, ymin, ymax, zmin, zmax: Float;
  end;

type
  IEvaluator = interface
    function GetValue(X, Y, Z: Float): Float;
    function GetConstraints: TConstraints;
  end;

const
  DSMALL = 0.00001;

type
{** grid point used for the marching cubes algorithm}
  TGridPoint = record
    P: Vector3;  // Grid position
    N: Vector3;  // Vertex normal
    Value: Float; // result of the F(x) at this point
  end;
  //PGridPoint = ^TGridPoint;

{** the "marching cubes" - pointers into the grid. 8 pts to a cube}
  // The actual "marching cubes":
  TGridCell = record
    P: array [0..7] of TGridPoint;
  end;

type
  //TEvalFunc = function(X, Y, Z: Float): Float of object;
  TGridPointMatrix = record
    Values: array of TGridPoint;
    nx, ny, nz: Integer;
    function GetIndex(X, Y, Z: Integer): Integer;
    function GetValue(X, Y, Z: Integer): TGridPoint;
    procedure SetValue(X, Y, Z: Integer; Value: TGridPoint);
    procedure SetSize(res_x, res_y, res_z: Integer);
  end;

  //array of array of array of TGridPoint;
  TGridCellMatrix = record
    Values: array of TGridCell;
    nx, ny, nz: Integer;
    function GetIndex(X, Y, Z: Integer): Integer;
    function GetValue(X, Y, Z: Integer): TGridCell;
    procedure SetValue(X, Y, Z: Integer; Value: TGridCell);
    procedure SetSize(res_x, res_y, res_z: Integer);
  end;

procedure EvaluateAllPoints(var Cells: TGridCellMatrix; n_res: Integer;
  const Constraints: TConstraints; var Vertices, Normals: TVertices);
procedure MarchingCubes(n_res: Integer; 
  Evaluator: IEvaluator; var Vertices, Normals: TVertices);
procedure TriangulateCell(grid: TGridCell; const Constraints: TConstraints;
  var Vertices, Normals: TVertices);
function Interpolate(p1, p2: Vector3; valp1, valp2: Float):Vector3;

const
  EDGETABLE: array [0..255] of Integer = (
    $0  , $109, $203, $30a, $406, $50f, $605, $70c,
    $80c, $905, $a0f, $b06, $c0a, $d03, $e09, $f00,
    $190, $99 , $393, $29a, $596, $49f, $795, $69c,
    $99c, $895, $b9f, $a96, $d9a, $c93, $f99, $e90,
    $230, $339, $33 , $13a, $636, $73f, $435, $53c,
    $a3c, $b35, $83f, $936, $e3a, $f33, $c39, $d30,
    $3a0, $2a9, $1a3, $aa , $7a6, $6af, $5a5, $4ac,
    $bac, $aa5, $9af, $8a6, $faa, $ea3, $da9, $ca0,
    $460, $569, $663, $76a, $66 , $16f, $265, $36c,
    $c6c, $d65, $e6f, $f66, $86a, $963, $a69, $b60,
    $5f0, $4f9, $7f3, $6fa, $1f6, $ff , $3f5, $2fc,
    $dfc, $cf5, $fff, $ef6, $9fa, $8f3, $bf9, $af0,
    $650, $759, $453, $55a, $256, $35f, $55 , $15c,
    $e5c, $f55, $c5f, $d56, $a5a, $b53, $859, $950,
    $7c0, $6c9, $5c3, $4ca, $3c6, $2cf, $1c5, $cc ,
    $fcc, $ec5, $dcf, $cc6, $bca, $ac3, $9c9, $8c0,
    $8c0, $9c9, $ac3, $bca, $cc6, $dcf, $ec5, $fcc,
    $cc , $1c5, $2cf, $3c6, $4ca, $5c3, $6c9, $7c0,
    $950, $859, $b53, $a5a, $d56, $c5f, $f55, $e5c,
    $15c, $55 , $35f, $256, $55a, $453, $759, $650,
    $af0, $bf9, $8f3, $9fa, $ef6, $fff, $cf5, $dfc,
    $2fc, $3f5, $ff , $1f6, $6fa, $7f3, $4f9, $5f0,
    $b60, $a69, $963, $86a, $f66, $e6f, $d65, $c6c,
    $36c, $265, $16f, $66 , $76a, $663, $569, $460,
    $ca0, $da9, $ea3, $faa, $8a6, $9af, $aa5, $bac,
    $4ac, $5a5, $6af, $7a6, $aa , $1a3, $2a9, $3a0,
    $d30, $c39, $f33, $e3a, $936, $83f, $b35, $a3c,
    $53c, $435, $73f, $636, $13a, $33 , $339, $230,
    $e90, $f99, $c93, $d9a, $a96, $b9f, $895, $99c,
    $69c, $795, $49f, $596, $29a, $393, $99 , $190,
    $f00, $e09, $d03, $c0a, $b06, $a0f, $905, $80c,
    $70c, $605, $50f, $406, $30a, $203, $109, $0);

  TRITABLE: array [0..255, 0..15] of Integer = [
    [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [0, 8, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [0, 1, 9, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [1, 8, 3, 9, 8, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [1, 2, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [0, 8, 3, 1, 2, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [9, 2, 10, 0, 2, 9, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [2, 8, 3, 2, 10, 8, 10, 9, 8, -1, -1, -1, -1, -1, -1, -1],
    [3, 11, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [0, 11, 2, 8, 11, 0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [1, 9, 0, 2, 3, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [1, 11, 2, 1, 9, 11, 9, 8, 11, -1, -1, -1, -1, -1, -1, -1],
    [3, 10, 1, 11, 10, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [0, 10, 1, 0, 8, 10, 8, 11, 10, -1, -1, -1, -1, -1, -1, -1],
    [3, 9, 0, 3, 11, 9, 11, 10, 9, -1, -1, -1, -1, -1, -1, -1],
    [9, 8, 10, 10, 8, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [4, 7, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [4, 3, 0, 7, 3, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [0, 1, 9, 8, 4, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [4, 1, 9, 4, 7, 1, 7, 3, 1, -1, -1, -1, -1, -1, -1, -1],
    [1, 2, 10, 8, 4, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [3, 4, 7, 3, 0, 4, 1, 2, 10, -1, -1, -1, -1, -1, -1, -1],
    [9, 2, 10, 9, 0, 2, 8, 4, 7, -1, -1, -1, -1, -1, -1, -1],
    [2, 10, 9, 2, 9, 7, 2, 7, 3, 7, 9, 4, -1, -1, -1, -1],
    [8, 4, 7, 3, 11, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [11, 4, 7, 11, 2, 4, 2, 0, 4, -1, -1, -1, -1, -1, -1, -1],
    [9, 0, 1, 8, 4, 7, 2, 3, 11, -1, -1, -1, -1, -1, -1, -1],
    [4, 7, 11, 9, 4, 11, 9, 11, 2, 9, 2, 1, -1, -1, -1, -1],
    [3, 10, 1, 3, 11, 10, 7, 8, 4, -1, -1, -1, -1, -1, -1, -1],
    [1, 11, 10, 1, 4, 11, 1, 0, 4, 7, 11, 4, -1, -1, -1, -1],
    [4, 7, 8, 9, 0, 11, 9, 11, 10, 11, 0, 3, -1, -1, -1, -1],
    [4, 7, 11, 4, 11, 9, 9, 11, 10, -1, -1, -1, -1, -1, -1, -1],
    [9, 5, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [9, 5, 4, 0, 8, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [0, 5, 4, 1, 5, 0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [8, 5, 4, 8, 3, 5, 3, 1, 5, -1, -1, -1, -1, -1, -1, -1],
    [1, 2, 10, 9, 5, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [3, 0, 8, 1, 2, 10, 4, 9, 5, -1, -1, -1, -1, -1, -1, -1],
    [5, 2, 10, 5, 4, 2, 4, 0, 2, -1, -1, -1, -1, -1, -1, -1],
    [2, 10, 5, 3, 2, 5, 3, 5, 4, 3, 4, 8, -1, -1, -1, -1],
    [9, 5, 4, 2, 3, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [0, 11, 2, 0, 8, 11, 4, 9, 5, -1, -1, -1, -1, -1, -1, -1],
    [0, 5, 4, 0, 1, 5, 2, 3, 11, -1, -1, -1, -1, -1, -1, -1],
    [2, 1, 5, 2, 5, 8, 2, 8, 11, 4, 8, 5, -1, -1, -1, -1],
    [10, 3, 11, 10, 1, 3, 9, 5, 4, -1, -1, -1, -1, -1, -1, -1],
    [4, 9, 5, 0, 8, 1, 8, 10, 1, 8, 11, 10, -1, -1, -1, -1],
    [5, 4, 0, 5, 0, 11, 5, 11, 10, 11, 0, 3, -1, -1, -1, -1],
    [5, 4, 8, 5, 8, 10, 10, 8, 11, -1, -1, -1, -1, -1, -1, -1],
    [9, 7, 8, 5, 7, 9, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [9, 3, 0, 9, 5, 3, 5, 7, 3, -1, -1, -1, -1, -1, -1, -1],
    [0, 7, 8, 0, 1, 7, 1, 5, 7, -1, -1, -1, -1, -1, -1, -1],
    [1, 5, 3, 3, 5, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [9, 7, 8, 9, 5, 7, 10, 1, 2, -1, -1, -1, -1, -1, -1, -1],
    [10, 1, 2, 9, 5, 0, 5, 3, 0, 5, 7, 3, -1, -1, -1, -1],
    [8, 0, 2, 8, 2, 5, 8, 5, 7, 10, 5, 2, -1, -1, -1, -1],
    [2, 10, 5, 2, 5, 3, 3, 5, 7, -1, -1, -1, -1, -1, -1, -1],
    [7, 9, 5, 7, 8, 9, 3, 11, 2, -1, -1, -1, -1, -1, -1, -1],
    [9, 5, 7, 9, 7, 2, 9, 2, 0, 2, 7, 11, -1, -1, -1, -1],
    [2, 3, 11, 0, 1, 8, 1, 7, 8, 1, 5, 7, -1, -1, -1, -1],
    [11, 2, 1, 11, 1, 7, 7, 1, 5, -1, -1, -1, -1, -1, -1, -1],
    [9, 5, 8, 8, 5, 7, 10, 1, 3, 10, 3, 11, -1, -1, -1, -1],
    [5, 7, 0, 5, 0, 9, 7, 11, 0, 1, 0, 10, 11, 10, 0, -1],
    [11, 10, 0, 11, 0, 3, 10, 5, 0, 8, 0, 7, 5, 7, 0, -1],
    [11, 10, 5, 7, 11, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [10, 6, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [0, 8, 3, 5, 10, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [9, 0, 1, 5, 10, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [1, 8, 3, 1, 9, 8, 5, 10, 6, -1, -1, -1, -1, -1, -1, -1],
    [1, 6, 5, 2, 6, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [1, 6, 5, 1, 2, 6, 3, 0, 8, -1, -1, -1, -1, -1, -1, -1],
    [9, 6, 5, 9, 0, 6, 0, 2, 6, -1, -1, -1, -1, -1, -1, -1],
    [5, 9, 8, 5, 8, 2, 5, 2, 6, 3, 2, 8, -1, -1, -1, -1],
    [2, 3, 11, 10, 6, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [11, 0, 8, 11, 2, 0, 10, 6, 5, -1, -1, -1, -1, -1, -1, -1],
    [0, 1, 9, 2, 3, 11, 5, 10, 6, -1, -1, -1, -1, -1, -1, -1],
    [5, 10, 6, 1, 9, 2, 9, 11, 2, 9, 8, 11, -1, -1, -1, -1],
    [6, 3, 11, 6, 5, 3, 5, 1, 3, -1, -1, -1, -1, -1, -1, -1],
    [0, 8, 11, 0, 11, 5, 0, 5, 1, 5, 11, 6, -1, -1, -1, -1],
    [3, 11, 6, 0, 3, 6, 0, 6, 5, 0, 5, 9, -1, -1, -1, -1],
    [6, 5, 9, 6, 9, 11, 11, 9, 8, -1, -1, -1, -1, -1, -1, -1],
    [5, 10, 6, 4, 7, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [4, 3, 0, 4, 7, 3, 6, 5, 10, -1, -1, -1, -1, -1, -1, -1],
    [1, 9, 0, 5, 10, 6, 8, 4, 7, -1, -1, -1, -1, -1, -1, -1],
    [10, 6, 5, 1, 9, 7, 1, 7, 3, 7, 9, 4, -1, -1, -1, -1],
    [6, 1, 2, 6, 5, 1, 4, 7, 8, -1, -1, -1, -1, -1, -1, -1],
    [1, 2, 5, 5, 2, 6, 3, 0, 4, 3, 4, 7, -1, -1, -1, -1],
    [8, 4, 7, 9, 0, 5, 0, 6, 5, 0, 2, 6, -1, -1, -1, -1],
    [7, 3, 9, 7, 9, 4, 3, 2, 9, 5, 9, 6, 2, 6, 9, -1],
    [3, 11, 2, 7, 8, 4, 10, 6, 5, -1, -1, -1, -1, -1, -1, -1],
    [5, 10, 6, 4, 7, 2, 4, 2, 0, 2, 7, 11, -1, -1, -1, -1],
    [0, 1, 9, 4, 7, 8, 2, 3, 11, 5, 10, 6, -1, -1, -1, -1],
    [9, 2, 1, 9, 11, 2, 9, 4, 11, 7, 11, 4, 5, 10, 6, -1],
    [8, 4, 7, 3, 11, 5, 3, 5, 1, 5, 11, 6, -1, -1, -1, -1],
    [5, 1, 11, 5, 11, 6, 1, 0, 11, 7, 11, 4, 0, 4, 11, -1],
    [0, 5, 9, 0, 6, 5, 0, 3, 6, 11, 6, 3, 8, 4, 7, -1],
    [6, 5, 9, 6, 9, 11, 4, 7, 9, 7, 11, 9, -1, -1, -1, -1],
    [10, 4, 9, 6, 4, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [4, 10, 6, 4, 9, 10, 0, 8, 3, -1, -1, -1, -1, -1, -1, -1],
    [10, 0, 1, 10, 6, 0, 6, 4, 0, -1, -1, -1, -1, -1, -1, -1],
    [8, 3, 1, 8, 1, 6, 8, 6, 4, 6, 1, 10, -1, -1, -1, -1],
    [1, 4, 9, 1, 2, 4, 2, 6, 4, -1, -1, -1, -1, -1, -1, -1],
    [3, 0, 8, 1, 2, 9, 2, 4, 9, 2, 6, 4, -1, -1, -1, -1],
    [0, 2, 4, 4, 2, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [8, 3, 2, 8, 2, 4, 4, 2, 6, -1, -1, -1, -1, -1, -1, -1],
    [10, 4, 9, 10, 6, 4, 11, 2, 3, -1, -1, -1, -1, -1, -1, -1],
    [0, 8, 2, 2, 8, 11, 4, 9, 10, 4, 10, 6, -1, -1, -1, -1],
    [3, 11, 2, 0, 1, 6, 0, 6, 4, 6, 1, 10, -1, -1, -1, -1],
    [6, 4, 1, 6, 1, 10, 4, 8, 1, 2, 1, 11, 8, 11, 1, -1],
    [9, 6, 4, 9, 3, 6, 9, 1, 3, 11, 6, 3, -1, -1, -1, -1],
    [8, 11, 1, 8, 1, 0, 11, 6, 1, 9, 1, 4, 6, 4, 1, -1],
    [3, 11, 6, 3, 6, 0, 0, 6, 4, -1, -1, -1, -1, -1, -1, -1],
    [6, 4, 8, 11, 6, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [7, 10, 6, 7, 8, 10, 8, 9, 10, -1, -1, -1, -1, -1, -1, -1],
    [0, 7, 3, 0, 10, 7, 0, 9, 10, 6, 7, 10, -1, -1, -1, -1],
    [10, 6, 7, 1, 10, 7, 1, 7, 8, 1, 8, 0, -1, -1, -1, -1],
    [10, 6, 7, 10, 7, 1, 1, 7, 3, -1, -1, -1, -1, -1, -1, -1],
    [1, 2, 6, 1, 6, 8, 1, 8, 9, 8, 6, 7, -1, -1, -1, -1],
    [2, 6, 9, 2, 9, 1, 6, 7, 9, 0, 9, 3, 7, 3, 9, -1],
    [7, 8, 0, 7, 0, 6, 6, 0, 2, -1, -1, -1, -1, -1, -1, -1],
    [7, 3, 2, 6, 7, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [2, 3, 11, 10, 6, 8, 10, 8, 9, 8, 6, 7, -1, -1, -1, -1],
    [2, 0, 7, 2, 7, 11, 0, 9, 7, 6, 7, 10, 9, 10, 7, -1],
    [1, 8, 0, 1, 7, 8, 1, 10, 7, 6, 7, 10, 2, 3, 11, -1],
    [11, 2, 1, 11, 1, 7, 10, 6, 1, 6, 7, 1, -1, -1, -1, -1],
    [8, 9, 6, 8, 6, 7, 9, 1, 6, 11, 6, 3, 1, 3, 6, -1],
    [0, 9, 1, 11, 6, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [7, 8, 0, 7, 0, 6, 3, 11, 0, 11, 6, 0, -1, -1, -1, -1],
    [7, 11, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [7, 6, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [3, 0, 8, 11, 7, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [0, 1, 9, 11, 7, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [8, 1, 9, 8, 3, 1, 11, 7, 6, -1, -1, -1, -1, -1, -1, -1],
    [10, 1, 2, 6, 11, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [1, 2, 10, 3, 0, 8, 6, 11, 7, -1, -1, -1, -1, -1, -1, -1],
    [2, 9, 0, 2, 10, 9, 6, 11, 7, -1, -1, -1, -1, -1, -1, -1],
    [6, 11, 7, 2, 10, 3, 10, 8, 3, 10, 9, 8, -1, -1, -1, -1],
    [7, 2, 3, 6, 2, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [7, 0, 8, 7, 6, 0, 6, 2, 0, -1, -1, -1, -1, -1, -1, -1],
    [2, 7, 6, 2, 3, 7, 0, 1, 9, -1, -1, -1, -1, -1, -1, -1],
    [1, 6, 2, 1, 8, 6, 1, 9, 8, 8, 7, 6, -1, -1, -1, -1],
    [10, 7, 6, 10, 1, 7, 1, 3, 7, -1, -1, -1, -1, -1, -1, -1],
    [10, 7, 6, 1, 7, 10, 1, 8, 7, 1, 0, 8, -1, -1, -1, -1],
    [0, 3, 7, 0, 7, 10, 0, 10, 9, 6, 10, 7, -1, -1, -1, -1],
    [7, 6, 10, 7, 10, 8, 8, 10, 9, -1, -1, -1, -1, -1, -1, -1],
    [6, 8, 4, 11, 8, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [3, 6, 11, 3, 0, 6, 0, 4, 6, -1, -1, -1, -1, -1, -1, -1],
    [8, 6, 11, 8, 4, 6, 9, 0, 1, -1, -1, -1, -1, -1, -1, -1],
    [9, 4, 6, 9, 6, 3, 9, 3, 1, 11, 3, 6, -1, -1, -1, -1],
    [6, 8, 4, 6, 11, 8, 2, 10, 1, -1, -1, -1, -1, -1, -1, -1],
    [1, 2, 10, 3, 0, 11, 0, 6, 11, 0, 4, 6, -1, -1, -1, -1],
    [4, 11, 8, 4, 6, 11, 0, 2, 9, 2, 10, 9, -1, -1, -1, -1],
    [10, 9, 3, 10, 3, 2, 9, 4, 3, 11, 3, 6, 4, 6, 3, -1],
    [8, 2, 3, 8, 4, 2, 4, 6, 2, -1, -1, -1, -1, -1, -1, -1],
    [0, 4, 2, 4, 6, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [1, 9, 0, 2, 3, 4, 2, 4, 6, 4, 3, 8, -1, -1, -1, -1],
    [1, 9, 4, 1, 4, 2, 2, 4, 6, -1, -1, -1, -1, -1, -1, -1],
    [8, 1, 3, 8, 6, 1, 8, 4, 6, 6, 10, 1, -1, -1, -1, -1],
    [10, 1, 0, 10, 0, 6, 6, 0, 4, -1, -1, -1, -1, -1, -1, -1],
    [4, 6, 3, 4, 3, 8, 6, 10, 3, 0, 3, 9, 10, 9, 3, -1],
    [10, 9, 4, 6, 10, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [4, 9, 5, 7, 6, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [0, 8, 3, 4, 9, 5, 11, 7, 6, -1, -1, -1, -1, -1, -1, -1],
    [5, 0, 1, 5, 4, 0, 7, 6, 11, -1, -1, -1, -1, -1, -1, -1],
    [11, 7, 6, 8, 3, 4, 3, 5, 4, 3, 1, 5, -1, -1, -1, -1],
    [9, 5, 4, 10, 1, 2, 7, 6, 11, -1, -1, -1, -1, -1, -1, -1],
    [6, 11, 7, 1, 2, 10, 0, 8, 3, 4, 9, 5, -1, -1, -1, -1],
    [7, 6, 11, 5, 4, 10, 4, 2, 10, 4, 0, 2, -1, -1, -1, -1],
    [3, 4, 8, 3, 5, 4, 3, 2, 5, 10, 5, 2, 11, 7, 6, -1],
    [7, 2, 3, 7, 6, 2, 5, 4, 9, -1, -1, -1, -1, -1, -1, -1],
    [9, 5, 4, 0, 8, 6, 0, 6, 2, 6, 8, 7, -1, -1, -1, -1],
    [3, 6, 2, 3, 7, 6, 1, 5, 0, 5, 4, 0, -1, -1, -1, -1],
    [6, 2, 8, 6, 8, 7, 2, 1, 8, 4, 8, 5, 1, 5, 8, -1],
    [9, 5, 4, 10, 1, 6, 1, 7, 6, 1, 3, 7, -1, -1, -1, -1],
    [1, 6, 10, 1, 7, 6, 1, 0, 7, 8, 7, 0, 9, 5, 4, -1],
    [4, 0, 10, 4, 10, 5, 0, 3, 10, 6, 10, 7, 3, 7, 10, -1],
    [7, 6, 10, 7, 10, 8, 5, 4, 10, 4, 8, 10, -1, -1, -1, -1],
    [6, 9, 5, 6, 11, 9, 11, 8, 9, -1, -1, -1, -1, -1, -1, -1],
    [3, 6, 11, 0, 6, 3, 0, 5, 6, 0, 9, 5, -1, -1, -1, -1],
    [0, 11, 8, 0, 5, 11, 0, 1, 5, 5, 6, 11, -1, -1, -1, -1],
    [6, 11, 3, 6, 3, 5, 5, 3, 1, -1, -1, -1, -1, -1, -1, -1],
    [1, 2, 10, 9, 5, 11, 9, 11, 8, 11, 5, 6, -1, -1, -1, -1],
    [0, 11, 3, 0, 6, 11, 0, 9, 6, 5, 6, 9, 1, 2, 10, -1],
    [11, 8, 5, 11, 5, 6, 8, 0, 5, 10, 5, 2, 0, 2, 5, -1],
    [6, 11, 3, 6, 3, 5, 2, 10, 3, 10, 5, 3, -1, -1, -1, -1],
    [5, 8, 9, 5, 2, 8, 5, 6, 2, 3, 8, 2, -1, -1, -1, -1],
    [9, 5, 6, 9, 6, 0, 0, 6, 2, -1, -1, -1, -1, -1, -1, -1],
    [1, 5, 8, 1, 8, 0, 5, 6, 8, 3, 8, 2, 6, 2, 8, -1],
    [1, 5, 6, 2, 1, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [1, 3, 6, 1, 6, 10, 3, 8, 6, 5, 6, 9, 8, 9, 6, -1],
    [10, 1, 0, 10, 0, 6, 9, 5, 0, 5, 6, 0, -1, -1, -1, -1],
    [0, 3, 8, 5, 6, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [10, 5, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [11, 5, 10, 7, 5, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [11, 5, 10, 11, 7, 5, 8, 3, 0, -1, -1, -1, -1, -1, -1, -1],
    [5, 11, 7, 5, 10, 11, 1, 9, 0, -1, -1, -1, -1, -1, -1, -1],
    [10, 7, 5, 10, 11, 7, 9, 8, 1, 8, 3, 1, -1, -1, -1, -1],
    [11, 1, 2, 11, 7, 1, 7, 5, 1, -1, -1, -1, -1, -1, -1, -1],
    [0, 8, 3, 1, 2, 7, 1, 7, 5, 7, 2, 11, -1, -1, -1, -1],
    [9, 7, 5, 9, 2, 7, 9, 0, 2, 2, 11, 7, -1, -1, -1, -1],
    [7, 5, 2, 7, 2, 11, 5, 9, 2, 3, 2, 8, 9, 8, 2, -1],
    [2, 5, 10, 2, 3, 5, 3, 7, 5, -1, -1, -1, -1, -1, -1, -1],
    [8, 2, 0, 8, 5, 2, 8, 7, 5, 10, 2, 5, -1, -1, -1, -1],
    [9, 0, 1, 5, 10, 3, 5, 3, 7, 3, 10, 2, -1, -1, -1, -1],
    [9, 8, 2, 9, 2, 1, 8, 7, 2, 10, 2, 5, 7, 5, 2, -1],
    [1, 3, 5, 3, 7, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [0, 8, 7, 0, 7, 1, 1, 7, 5, -1, -1, -1, -1, -1, -1, -1],
    [9, 0, 3, 9, 3, 5, 5, 3, 7, -1, -1, -1, -1, -1, -1, -1],
    [9, 8, 7, 5, 9, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [5, 8, 4, 5, 10, 8, 10, 11, 8, -1, -1, -1, -1, -1, -1, -1],
    [5, 0, 4, 5, 11, 0, 5, 10, 11, 11, 3, 0, -1, -1, -1, -1],
    [0, 1, 9, 8, 4, 10, 8, 10, 11, 10, 4, 5, -1, -1, -1, -1],
    [10, 11, 4, 10, 4, 5, 11, 3, 4, 9, 4, 1, 3, 1, 4, -1],
    [2, 5, 1, 2, 8, 5, 2, 11, 8, 4, 5, 8, -1, -1, -1, -1],
    [0, 4, 11, 0, 11, 3, 4, 5, 11, 2, 11, 1, 5, 1, 11, -1],
    [0, 2, 5, 0, 5, 9, 2, 11, 5, 4, 5, 8, 11, 8, 5, -1],
    [9, 4, 5, 2, 11, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [2, 5, 10, 3, 5, 2, 3, 4, 5, 3, 8, 4, -1, -1, -1, -1],
    [5, 10, 2, 5, 2, 4, 4, 2, 0, -1, -1, -1, -1, -1, -1, -1],
    [3, 10, 2, 3, 5, 10, 3, 8, 5, 4, 5, 8, 0, 1, 9, -1],
    [5, 10, 2, 5, 2, 4, 1, 9, 2, 9, 4, 2, -1, -1, -1, -1],
    [8, 4, 5, 8, 5, 3, 3, 5, 1, -1, -1, -1, -1, -1, -1, -1],
    [0, 4, 5, 1, 0, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [8, 4, 5, 8, 5, 3, 9, 0, 5, 0, 3, 5, -1, -1, -1, -1],
    [9, 4, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [4, 11, 7, 4, 9, 11, 9, 10, 11, -1, -1, -1, -1, -1, -1, -1],
    [0, 8, 3, 4, 9, 7, 9, 11, 7, 9, 10, 11, -1, -1, -1, -1],
    [1, 10, 11, 1, 11, 4, 1, 4, 0, 7, 4, 11, -1, -1, -1, -1],
    [3, 1, 4, 3, 4, 8, 1, 10, 4, 7, 4, 11, 10, 11, 4, -1],
    [4, 11, 7, 9, 11, 4, 9, 2, 11, 9, 1, 2, -1, -1, -1, -1],
    [9, 7, 4, 9, 11, 7, 9, 1, 11, 2, 11, 1, 0, 8, 3, -1],
    [11, 7, 4, 11, 4, 2, 2, 4, 0, -1, -1, -1, -1, -1, -1, -1],
    [11, 7, 4, 11, 4, 2, 8, 3, 4, 3, 2, 4, -1, -1, -1, -1],
    [2, 9, 10, 2, 7, 9, 2, 3, 7, 7, 4, 9, -1, -1, -1, -1],
    [9, 10, 7, 9, 7, 4, 10, 2, 7, 8, 7, 0, 2, 0, 7, -1],
    [3, 7, 10, 3, 10, 2, 7, 4, 10, 1, 10, 0, 4, 0, 10, -1],
    [1, 10, 2, 8, 7, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [4, 9, 1, 4, 1, 7, 7, 1, 3, -1, -1, -1, -1, -1, -1, -1],
    [4, 9, 1, 4, 1, 7, 0, 8, 1, 8, 7, 1, -1, -1, -1, -1],
    [4, 0, 3, 7, 4, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [4, 8, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [9, 10, 8, 10, 11, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [3, 0, 9, 3, 9, 11, 11, 9, 10, -1, -1, -1, -1, -1, -1, -1],
    [0, 1, 10, 0, 10, 8, 8, 10, 11, -1, -1, -1, -1, -1, -1, -1],
    [3, 1, 10, 11, 3, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [1, 2, 11, 1, 11, 9, 9, 11, 8, -1, -1, -1, -1, -1, -1, -1],
    [3, 0, 9, 3, 9, 11, 1, 2, 9, 2, 11, 9, -1, -1, -1, -1],
    [0, 2, 11, 8, 0, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [3, 2, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [2, 3, 8, 2, 8, 10, 10, 8, 9, -1, -1, -1, -1, -1, -1, -1],
    [9, 10, 2, 0, 9, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [2, 3, 8, 2, 8, 10, 0, 1, 8, 1, 10, 8, -1, -1, -1, -1],
    [1, 10, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [1, 3, 8, 9, 1, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [0, 9, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [0, 3, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1] ];

implementation

function Normalize(V: Vector3): Vector3;
var
  L: Float;
begin
  L := 1/Sqrt(Sqr(V[0]) + Sqr(V[1]) + Sqr(V[2]));
  Result[0] := V[0] * L;
  Result[1] := V[1] * L;
  Result[2] := V[2] * L;
end;

{ TGridPointMatrix }

function TGridPointMatrix.GetIndex(X, Y, Z: Integer): Integer;
begin
  Result := nx * (ny * z + y) + x;
end;

function TGridPointMatrix.GetValue(X, Y, Z: Integer): TGridPoint;
begin
  Result := Values[GetIndex(X, Y, Z)];
end;

procedure TGridPointMatrix.SetValue(X, Y, Z: Integer; Value: TGridPoint);
begin
  Values[GetIndex(X, Y, Z)] := Value;
end;

procedure TGridPointMatrix.SetSize(res_x, res_y, res_z: Integer);
begin
  nx := res_x;
  ny := res_y;
  nz := res_z;
  Values.SetLength(nx * ny * nz);
end;


{ TGridCellMatrix }

function TGridCellMatrix.GetIndex(X, Y, Z: Integer): Integer;
begin
  Result := nx * (ny * z + y) + x;
end;

function TGridCellMatrix.GetValue(X, Y, Z: Integer): TGridCell;
begin
  Result := Values[GetIndex(X, Y, Z)];
end;

procedure TGridCellMatrix.SetValue(X, Y, Z: Integer; Value: TGridCell);
begin
  Values[GetIndex(X, Y, Z)] := Value;
end;

procedure TGridCellMatrix.SetSize(res_x, res_y, res_z: Integer);
begin
  nx := res_x;
  ny := res_y;
  nz := res_z;
  Values.SetLength(nx * ny * nz);
end;


// ----- EvaluateAllPoints -----------------------------------------------------
procedure EvaluateAllPoints(var Cells: TGridCellMatrix; n_res: Integer;
  const Constraints: TConstraints; var Vertices, Normals: TVertices);
var
  x,y,z : integer;
begin
  for x := 0 to n_res-1 do
    for y := 0 to n_res-1 do
      for z := 0 to n_res-1 do
        TriangulateCell(CELLS.GetValue(x,y,z), Constraints, Vertices, Normals);
end;

// ----- InitializeMarchingCube ------------------------------------------------
{** the initialise section is used to initialise the grid's vertex positions
and to create the cells (the cubes). This only needs to be done once.
Afterwards only the metaball equation results need to be calculated for each
frame}
procedure InitializeMarchingCube(var Cells: TGridCellMatrix;
  n_res: Integer; const Constraints: TConstraints; Evaluator: IEvaluator);
var
  GRID : TGridPointMatrix;
//  CELLS : TGridCellMatrix;
  point: TGridPoint;
  cell: TGridCell;

  x,y,z: integer;
  incx, incy, incz: Float;
  px,py,pz: Float;
  xmax, xmin, ymax, ymin, zmax, zmin: Float;
begin
(*
  xmin := 0;        //fmMain.jvseMin.Value;  ?
  xmax := 100;      //fmMain.jvseMax.Value;
  ymin := 0;        //fmMain.jvseMin.Value;
  ymax := 100;      //fmMain.jvseMax.value;
  zmin := 0;        //fmMain.jvseMin.Value;
  zmax := 100;      //fmMain.jvseMax.value;

  n_res := 100;     //fmMain.jvseResolution.AsInteger;
*)
  xmax := Constraints.xmax;
  xmin := Constraints.xmin;
  ymax := Constraints.ymax;
  ymin := Constraints.ymin;
  zmax := Constraints.zmax;
  zmin := Constraints.zmin;

  incx := (xmax - xmin)/n_res;
  incy := (ymax - ymin)/n_res;
  incz := (zmax - zmin)/n_res;

  GRID.SetSize(n_res+1, n_res+1, n_res+1);
  CELLS.SetSize(n_res, n_res, n_res);

{** set grid positions}
  for x := 0 to n_res do
  begin
    px := xmin + incx*x;
    for y := 0 to n_res do
    begin
      py := ymin + incy*y;
      for z := 0 to n_res do
      begin
        pz := zmin + incz*z;
        Point.P[0] := px;
        Point.P[1] := py;
        Point.P[2] := pz;
        Point.Value := Evaluator.GetValue(px, py, pz);
        Point.N[0] := Point.Value - Evaluator.GetValue(px + DSMALL, py, pz);
        Point.N[1] := Point.Value - Evaluator.GetValue(px, py + DSMALL, pz);
        Point.N[2] := Point.Value - Evaluator.GetValue(px, py, pz + DSMALL);
        Point.N := Normalize(Point.N);
        GRID.SetValue(x,y,z, Point);
      end;
    end;
  end;

  // Create cubes:
  for x := 0 to n_res-1 do
  begin
    for y := 0 to n_res-1 do
    begin
      for z := 0 to n_res-1 do
      begin
        Cell.P[0] := GRID.GetValue(x, y, z);
        Cell.P[1] := GRID.GetValue(x+1, y, z);
        Cell.P[2] := GRID.GetValue(x+1, y, z+1);
        Cell.P[3] := GRID.GetValue(x, y, z+1);
        Cell.P[4] := GRID.GetValue(x, y+1, z);
        Cell.P[5] := GRID.GetValue(x+1, y+1, z);
        Cell.P[6] := GRID.GetValue(x+1, y+1, z+1);
        Cell.P[7] := GRID.GetValue(x, y+1, z+1);
        CELLS.SetValue(x,y,z, Cell);
      end;
    end;
  end;
end;

// ----- TriangulateCell -------------------------------------------------------
procedure TriangulateCell(grid: TGridCell; const Constraints: TConstraints;
  var Vertices, Normals: TVertices);
var
  i, cubeidx : integer;
  verts, norms: array [0..11] of Vector3;
begin
{** create triangle for the given grid cell. The triangles will be rendered
immediately. The cell's corner vertices need to have been initialized with the
correct values, of course}

{** determine the index into the edge table - its an implicit function}
  cubeidx := 0;
  if grid.P[0].Value > 0 then cubeidx := cubeidx or 1;
  if grid.P[1].Value > 0 then cubeidx := cubeidx or 2;
  if grid.P[2].Value > 0 then cubeidx := cubeidx or 4;
  if grid.P[3].Value > 0 then cubeidx := cubeidx or 8;
  if grid.P[4].Value > 0 then cubeidx := cubeidx or 16;
  if grid.P[5].Value > 0 then cubeidx := cubeidx or 32;
  if grid.P[6].Value > 0 then cubeidx := cubeidx or 64;
  if grid.P[7].Value > 0 then cubeidx := cubeidx or 128;

{** the edge table tells us which vertices are inside/outside the surface}
  if edgeTable[cubeidx] = 0 then
  begin
{** cube is entirely inside/outside the surface}
    Exit;
  end;

{** find the vertices where the surface intersects the cube, using interpolate}
  if (edgeTable[cubeidx] and 1) <> 0 then
  begin
    verts[0] := Interpolate(grid.P[0].P, grid.P[1].P, grid.P[0].Value, grid.P[1].Value);
    norms[0] := Interpolate(grid.P[0].N, grid.P[1].N, grid.P[0].Value, grid.P[1].Value);
  end;
  if (edgeTable[cubeidx] and 2) <> 0 then
  begin
    verts[1] := Interpolate(grid.P[1].P,grid.P[2].P,grid.P[1].Value,grid.P[2].Value);
    norms[1] := Interpolate(grid.P[1].N,grid.P[2].N,grid.P[1].Value,grid.P[2].Value);
  end;
  if (edgeTable[cubeidx] and 4) <> 0 then
  begin
    verts[2] := Interpolate(grid.P[2].P,grid.P[3].P,grid.P[2].Value,grid.P[3].Value);
    norms[2] := Interpolate(grid.P[2].N,grid.P[3].N,grid.P[2].Value,grid.P[3].Value);
  end;
  if (edgeTable[cubeidx] and 8) <> 0 then
  begin
    verts[3] := Interpolate(grid.P[3].P,grid.P[0].P,grid.P[3].Value,grid.P[0].Value);
    norms[3] := Interpolate(grid.P[3].N,grid.P[0].N,grid.P[3].Value,grid.P[0].Value);
  end;
  if (edgeTable[cubeidx] and 16) <> 0 then
  begin
    verts[4] := Interpolate(grid.P[4].P,grid.P[5].P,grid.P[4].Value,grid.P[5].Value);
    norms[4] := Interpolate(grid.P[4].N,grid.P[5].N,grid.P[4].Value,grid.P[5].Value);
  end;
  if (edgeTable[cubeidx] and 32) <> 0 then
  begin
    verts[5] := Interpolate(grid.P[5].P,grid.P[6].P,grid.P[5].Value,grid.P[6].Value);
    norms[5] := Interpolate(grid.P[5].N,grid.P[6].N,grid.P[5].Value,grid.P[6].Value);
  end;
  if (edgeTable[cubeidx] and 64) <> 0 then
  begin
    verts[6] := Interpolate(grid.P[6].P,grid.P[7].P,grid.P[6].Value,grid.P[7].Value);
    norms[6] := Interpolate(grid.P[6].N,grid.P[7].N,grid.P[6].Value,grid.P[7].Value);
  end;
  if (edgeTable[cubeidx] and 128) <> 0 then
  begin
    verts[7] := Interpolate(grid.P[7].P,grid.P[4].P,grid.P[7].Value,grid.P[4].Value);
    norms[7] := Interpolate(grid.P[7].N,grid.P[4].N,grid.P[7].Value,grid.P[4].Value);
  end;
  if (edgeTable[cubeidx] and 256) <> 0 then
  begin
    verts[8] := Interpolate(grid.P[0].P,grid.P[4].P,grid.P[0].Value,grid.P[4].Value);
    norms[8] := Interpolate(grid.P[0].N,grid.P[4].N,grid.P[0].Value,grid.P[4].Value);
  end;
  if (edgeTable[cubeidx] and 512) <> 0 then
  begin
    verts[9] := Interpolate(grid.P[1].P,grid.P[5].P,grid.P[1].Value,grid.P[5].Value);
    norms[9] := Interpolate(grid.P[1].N,grid.P[5].N,grid.P[1].Value,grid.P[5].Value);
  end;
  if (edgeTable[cubeidx] and 1024) <> 0 then
  begin
    verts[10] := Interpolate(grid.P[2].P,grid.P[6].P,grid.P[2].Value,grid.P[6].Value);
    norms[10] := Interpolate(grid.P[2].N,grid.P[6].N,grid.P[2].Value,grid.P[6].Value);
  end;
  if (edgeTable[cubeidx] and 2048) <> 0 then
  begin
    verts[11] := Interpolate(grid.P[3].P,grid.P[7].P,grid.P[3].Value,grid.P[7].Value);
    norms[11] := Interpolate(grid.P[3].N,grid.P[7].N,grid.P[3].Value,grid.P[7].Value);
  end;

// Create the triangle(s):
  i := 0;
  while TRITABLE[cubeidx, i] <> -1 do
  begin
    Vertices.Push(verts[triTable[cubeidx][i]]);
    Normals.Push(norms[triTable[cubeidx][i]]);
    Inc(i);
  end;
end;

// ----- Interpolate -----------------------------------------------------------
function Interpolate(p1,p2: Vector3;valp1,valp2: Float):Vector3;

var
  mu : Float;
  p : Vector3;

begin
{** estimate the point where the surface intersects the given edge of a cube
(the line segment [p1 p2], using linear interpolation. valp1,valp2 are the
results of the surface equations at the two edge vertices}
//  if (abs(1-valp1) < DSMALL) then
  if (abs(valp1) < DSMALL) then
  begin
{** p1 is on the surface}
    result := p1;
    exit;
  end;
//  if (abs(1-valp2) < DSMALL) then
  if (abs(valp2) < DSMALL) then
  begin
{** p2 is on the surface}
    result := p2;
    exit;
  end;

{** the given edge is entirely on the surface}
  if (abs(valp1 - valp2) < DSMALL) then
  begin
    result := p1;
    exit;
  end;

{** interpolate in all the other cases}
  //mu := (1 - valp1) / (valp2 - valp1);
  mu := valp1 / (valp1 - valp2);
  p[0] := p1[0] + mu * (p2[0] - p1[0]);
  p[1] := p1[1] + mu * (p2[1] - p1[1]);
  p[2] := p1[2] + mu * (p2[2] - p1[2]);

  result := p;
end;

procedure MarchingCubes(n_res: Integer; 
  Evaluator: IEvaluator; var Vertices, Normals: TVertices);
var
  CELLS : TGridCellMatrix;
  Constraints: TConstraints;
begin
  Constraints := Evaluator.GetConstraints;
  InitializeMarchingCube(Cells, n_res, Constraints, Evaluator);
  EvaluateAllPoints(Cells, n_res, Constraints, Vertices, Normals);
end;

function IEvaluator.GetConstraints: TConstraints;
begin
  Result.xmin := -1.0;
  Result.xmax :=  1.0;
  Result.ymin := -1.0;
  Result.ymax :=  1.0;
  Result.zmin := -1.0;
  Result.zmax :=  1.0;
end;

end.