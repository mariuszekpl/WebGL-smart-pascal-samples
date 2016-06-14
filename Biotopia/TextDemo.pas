unit TextDemo;

interface

uses
  Khronos.WebGL, GLS.Base, GLS.Vectors, GLCommon, Glyphs, MainForm, ShaderDemo;

type
  TTextDemoFragment = class(TShaderDemoFragment)
  private
    FText: string;
    FDistance: Float;
  protected
    function GetDuration: Float; override;
    procedure GetVertexData(var Data: TVertexData); override;
    function GetModelViewMatrix: Matrix4; override;
  public
    procedure Render; override;
    constructor Create(AText: string; ADistance: Float);
  end;

implementation

{ TTextDemoFragment }

procedure TTextDemoFragment.Render;
var
  projMat, mvMat : Matrix4;

  procedure DrawPoints(shaderProgram: TGLShaderProgram);
  begin
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.clear(gl.DEPTH_BUFFER_BIT);

    shaderProgram.Use;

    shaderProgram.SetUniform('uPMatrix', projMat);
    shaderProgram.SetUniform('uMVMatrix', mvMat);
    shaderProgram.SetUniform('uMVInvMatrix', mvMat.ToMatrix3.Inverse);

    shaderProgram.SetUniform('color', ColorTexID);
    shaderProgram.SetUniform('depth', DepthTexID);
    shaderProgram.SetUniform('source_a', EnvironmentTexID1);
    shaderProgram.SetUniform('source_b', EnvironmentTexID2);
    shaderProgram.SetUniform('source_c', EnvironmentTexID3);
    shaderProgram.SetUniform('source_d', EnvironmentTexID4);

    gl.enableVertexAttribArray(vertexPosAttrib);
    gl.enableVertexAttribArray(vertexNormalAttrib);
    gl.enableVertexAttribArray(vertexWeightAttrib);

    VertexBuffer.VertexAttribPointer(vertexPosAttrib, 3, false, 0, 0);
    NormalBuffer.VertexAttribPointer(vertexNormalAttrib, 3, false, 0, 0);
    WeightBuffer.VertexAttribPointer(vertexWeightAttrib, 3, false, 0, 0);
    gl.drawArrays(gl.TRIANGLES, 0, nverts);
  end;

begin
  projMat := GetProjectionMatrix;
  mvMat := GetModelViewMatrix;

  gl.bindFramebuffer(gl.FRAMEBUFFER, nil);
  DrawPoints(shaderProgram);
end;

function TTextDemoFragment.GetDuration: Float;
begin
  Result := 10;
end;

function TTextDemoFragment.GetModelViewMatrix: Matrix4;
begin
  Result := Matrix4.Identity;
  //Result := Result.Translate([4 - ReadTimer, 0, -11]);
  Result := Result.Translate([0, 0, -FDistance]);
  Result := Result.RotateX(Sin(Frac(ReadTimer*0.3)*2*Pi)*0.5 + 135); // + 90);
end;

procedure ExtrudeTriStrip(Delta: Vector3;
  var Verts, Norms: TVertices);
var
  U: TVertices;
  V: array [0..2] of Vector3;
  I: Integer;
  N, W: Vector3;

  procedure AddSquare(U1, U2, V1, V2: Vector3);
  begin
    N := U1.Sub(U2).Cross([0,0,-1]).Normalize;
    Verts.Push(U1);
    Verts.Push(U2);
    Verts.Push(V1);
    Verts.Push(U2);
    Verts.Push(V1);
    Verts.Push(V2);

    Norms.Push(N);
    Norms.Push(N);
    Norms.Push(N);
    Norms.Push(N);
    Norms.Push(N);
    Norms.Push(N);
  end;

begin
  U := Verts.Copy(0, Length(Verts));
  Verts := [];
  Norms := [];
  W := U[0];
  I := 0;
  while I < High(U)-2 do
  begin
    if W.Dist2(U[I+1]) = 0.0 then
    begin
      Inc(I);
    end
    else
    begin
      Verts.Push(U[I]);
      Verts.Push(U[I+1]);
      Verts.Push(U[I+2]);
      Norms.Push([0.0,0.0,1.0]);
      Norms.Push([0.0,0.0,1.0]);
      Norms.Push([0.0,0.0,1.0]);

      V[0] := U[I].Add(Delta);
      V[1] := U[I+1].Add(Delta);
      V[2] := U[I+2].Add(Delta);
      Verts.Push(V[0]);
      Verts.Push(V[1]);
      Verts.Push(V[2]);
      Norms.Push([0.0,0.0,-1.0]);
      Norms.Push([0.0,0.0,-1.0]);
      Norms.Push([0.0,0.0,-1.0]);

      AddSquare(U[I], U[I+1], V[0], V[1]);
      AddSquare(U[I+1], U[I+2], V[1], V[2]);
      AddSquare(U[I+2], U[I], V[2], V[0]);

      W := U[I+1];
    end;
    Inc(I);
  end;
end;

{ TTextDemoFragment }

constructor TTextDemoFragment.Create(AText: String; ADistance: Float);
begin
  inherited Create;
  FText := AText;
  FDistance := ADistance;
end;

function CountLines(const S: string): Integer;
var
  I: Integer;
begin
  Result := 1;
  for I := 1 to Length(S) do
    if S[I] = ';' then Inc(Result);
end;

procedure TTextDemoFragment.GetVertexData(var Data: TVertexData);
const
  LINESPACE = 1.5;
var
  I: Integer;
  s, q: string;
  dx, dy: Float;

  procedure ExtrudeText(Text: String);
  var
    V, N: TVertices;
    I: Integer;
  begin
    if Text = '' then Exit;
    dx := -TextWidth(Text) * 0.5;
    N := [];
    V := GetText(Text, dx, dy);
    //ShowMessage(Text);
    ExtrudeTriStrip([0, 0, -0.8], V, N);
    //ShowMessage(InttoStr(length(V)));    //Data.Normals := Normals;
    //Data.Vertices := Vertices;
    for I := 0 to High(V) do
    begin
      Data.Vertices.Push(V[I]);
      Data.Normals.Push(N[I]);
      Data.Weights.Push([0.0, 0.0, (V[I][1]-dy-0.5)*2]);
    end;
  end;

begin
  s := FText;
  I := 1;
  dx := 0; dy := -CountLines(s)*LINESPACE*0.5;
  q := '';
  while (I <= Length(s)) do
  begin
    if S[I] = ';' then
    begin
      ExtrudeText(q);
      dy := dy + LINESPACE;
      q := '';
    end
    else
      q := q + s[I];
    Inc(I);
  end;
  ExtrudeText(q);
end;

end.
