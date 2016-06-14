unit BiotopiaApp;

interface

uses
  SmartCL.System, SmartCL.Controls, SmartCL.Components, SmartCL.Forms, 
  SmartCL.Application, MainForm;

type
  TApplication = class(TW3CustomApplication)
  public
    procedure ApplicationStarting; override;
  end;

implementation

{ TApplication }

procedure TApplication.ApplicationStarting;
var
  mForm: TMainForm;
begin
  //Add code above this line 
  mForm := TMainForm.Create(display.view);
  mForm.name := 'Form1';
  RegisterFormInstance(mForm, true);
  inherited;
end;

end.