scriptname mlheur_SkyrimTimescale extends SKI_ConfigBase
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Changes
;
; 0:	Initial Development
;

; TODO	- add function parms to iLog and return values to oLog; done?
;	- Hotkey to show speed
;	- show a message when there's no further steps to take
;	- Log changes to the actual timescale

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Static values
int MinSpeed = 2
int MaxSpeed = 3600

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ESP values
globalvariable property Timescale auto
globalvariable property mlheur_STSKeySpeedUp auto
globalvariable property mlheur_STSKeyShowSpeed auto
globalvariable property mlheur_STSKeySpeedDn auto
globalvariable property mlheur_STSKeyMeta auto
globalvariable property mlheur_STSShowMessages auto
globalvariable property mlheur_STSDebugLevel auto

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Variables

; Ver 0 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

int[] Speeds
bool SettingsApplied = false
int _indent = 0
int TopSpeedIDX = 0

; MCM OIDs
; Options page
int oidShowMessages = 0
int oidKeySpeedUp = 0
int oidKeyShowSpeed = 0
int oidKeySpeedDn = 0
int oidKeyMeta = 0
int oidAdhocSpeed = 0
int oidDebugLevel = 0
; Timescale Steps
int[] oidSetSpeed
int[] oidDelSpeed
int oidNewSpeed = 0 ; not a true oid, but an index into oidSetSpeed past Speeds[]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MCM Events & Functions

int function GetVersion()
	iLog( "GetVersion()" )
	oLog( "GetVersion()=[0]" )
	return 0
endfunction

event OnConfigInit()
	iLog( "OnConfigInit()" )
	SettingsApplied = false
	Speeds = new int[32]
	InitSpeeds()
	if ! SettingsApplied
		ApplySettings()
	endif
	oLog( "OnConfigInit()=[]" )
endevent

event OnGameReload()
	_indent = 0
	iLog( "OnGameReload()" )
	SettingsApplied = false
	parent.OnGameReload()
	if ! SettingsApplied
		ApplySettings()
	endif
	oLog( "OnGameReload()=[]" )
endevent

event OnVersionUpdate( int newVersion )
	iLog( "OnVersionUpdate( newVersion=["+newVersion+"] )" )
	oLog( "OnVersionUpdate()=[]" )
endevent

event OnPageReset( string Page )
	iLog( "OnPageReset( Page=["+Page+"] )" )
	UnloadCustomContent();
	if Page == Pages[0]
		ShowOptions()
	elseif Page == Pages[1]
		ShowSpeeds()
	else
		LoadCustomContent( "mlheur_SkyrimTimescale.dds" );
	endif
	DumpSpeeds( "OnPageReset", 5 );
	oLog( "OnPageReset()=[]" )
endevent

event OnOptionSelect( int oid )
	iLog( "OnOptionSelect( oid=["+oid+"] )" )
	if CurrentPage == Pages[0]
		UpdateOption( oid )
	elseif CurrentPage == Pages[1]
		UpdateSpeed( oid, MaxSpeed+1 )
	endif
	ForcePageReset()
	oLog( "OnOptionSelect()=[]" )
endevent

event OnOptionKeyMapChange( int oid, int keycode, string UsedFor, string UsedBy )
	iLog( "OnKeyMapChange( oid=["+oid+"], keycode=["+keycode+"], UsedFor=["+UsedFor+"], UsedBy=["+UsedBy+"] )" )
	if UsedFor || UsedBy
		; TODO - translations
		ShowMessage( "Key in use for "+UsedFor+" by "+UsedBy )
	elseif CurrentPage == Pages[0]
		ChangeKeyMapOption( oid, keycode )
	endif
	ForcePageReset()
	oLog( "OnKeyMapChange()=[]" )
endevent

event OnOptionSliderOpen( int oid )
	iLog( "OnOptionSliderOpen( oid=["+oid+"] )" )
	if CurrentPage == Pages[0]
		ShowOptionSlider( oid )
	elseif CurrentPage == Pages[1]
		ShowSpeedSlider( oid )
	endif
	oLog( "OnOptionSliderOpen()=[]" )
endevent

event OnOptionSliderAccept( int oid, float value )
	iLog( "OnOptionSliderSelect( oid=["+oid+"], value=["+value+"] )" )
	if CurrentPage == Pages[0]
		UpdateOption( oid, value as int )
	elseif CurrentPage == Pages[1]
		if value < MinSpeed
			UpdateSpeed( oid, MinSpeed )
		elseif value > MaxSpeed
			UpdateSpeed( oid, MaxSpeed )
		else
			UpdateSpeed( oid, value as int )
		endif
	endif
	ForcePageReset()
	oLog( "OnOptionSliderSelect()=[]" )
endevent

event OnKeyUp( int keycode, float duration )
	iLog( "OnKeyUp( keycode=["+keycode+"], duration=["+duration+"] )" )
	if IsAnyMenuOpen()
		oLog( "OnKeyUp" )
		return
	endif
	bool MetaKeyDown = Input.IsKeyPressed( mlheur_STSKeyMeta.GetValueInt() )
	if keycode == mlheur_STSKeySpeedUp.GetValueInt();
		if MetaKeyDown
			SetTimescale( Speeds[TopSpeedIDX] );
		else
			IncTimescale()
		endif
	elseif keycode == mlheur_STSKeySpeedDn.GetValueInt();
		if MetaKeyDown
			SetTimescale( Speeds[0] );
		else
			DecTimescale()
		endif
	elseif keycode == mlheur_STSKeyShowSpeed.GetValueInt();
		SetTimescale( Timescale.GetValueInt() );
;	elseif keycode == mlheur_STSKeyMeta.GetValueInt();
;		MetaKeyDown = false
	endif
	oLog( "OnKeyUp()=[]" )
endevent

;event OnKeyDown( int keycode )
;	iLog( "OnKeyDown( keycode=["+keycode+"] )" )
;	if IsAnyMenuOpen()
;		oLog( "OnKeyDown" )
;		return
;	endif
;	if keycode == mlheur_STSKeyMeta.GetValueInt();
;		Log( "MetaKeyDown changing to true", 2 )
;		MetaKeyDown = true
;	endif
;	oLog( "OnKeyDown()=[]" )
;endevent

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Internal Functions

function ApplySettings()
	iLog( "ApplySettings()" )
	Pages = new String[2]
	Pages[0] = "$STSOptions"
	Pages[1] = "$STSTimescaleSteps"
	SortSpeeds()
	SettingsApplied = true
	oLog( "ApplySettings()=[]" )
endfunction

function ShowOptions()
	iLog( "ShowOptions()" )
	SetCursorFillMode( TOP_TO_BOTTOM )
	oidShowMessages = AddToggleOption( "$STSShowMessages", mlheur_STSShowMessages.GetvalueInt() as bool )
	AddEmptyOption()
	oidKeySpeedUp = AddKeyMapOption( "$STSKeySpeedUp", mlheur_STSKeySpeedUp.GetvalueInt(), OPTION_FLAG_WITH_UNMAP )
	oidKeyShowSpeed = AddKeyMapOption( "$STSKeyShowSpeed", mlheur_STSKeyShowSpeed.GetvalueInt(), OPTION_FLAG_WITH_UNMAP )
	oidKeySpeedDn = AddKeyMapOption( "$STSKeySpeedDn", mlheur_STSKeySpeedDn.GetvalueInt(), OPTION_FLAG_WITH_UNMAP )
	oidKeyMeta = AddKeyMapOption( "$STSKeyMeta", mlheur_STSKeyMeta.GetvalueInt(), OPTION_FLAG_WITH_UNMAP )
	AddEmptyOption()
	oidAdhocSpeed = AddSliderOption( "$STSAdhocSpeed", Timescale.GetValueInt() )
	AddEmptyOption()
	oidDebugLevel = AddSliderOption( "$STSDebugLevel", mlheur_STSDebugLevel.GetValueInt() )
	oLog( "ShowOptions()=[]" )
endfunction

function ShowOptionSlider( int oid )
	iLog( "ShowOptionSlider( oid=["+oid+"] )" )
	float Cur = 0.0
	int Min = 0
	int Max = 0
	if oid == oidDebugLevel
		Min = 0
		Max = 5
		Cur = mlheur_STSDebugLevel.GetValue()
	elseif oid == oidAdhocSpeed
		Min = MinSpeed
		Max = MaxSpeed
		Cur = Timescale.GetValue()
	endif
	SetSliderDialogStartValue( Cur )
	SetSliderDialogDefaultValue( Cur )
	SetSliderDialogRange( Min as float, Max as float )
	SetSliderDialogInterval( 1.0 )
	oLog( "ShowOptionSlider()=[]" )
endfunction

function UpdateOption( int oid, int value = 0 )
	iLog( "UpdateOption( oid=["+oid+"], value=["+value+"] )" )
	if oid == oidShowMessages
		if mlheur_STSShowMessages.GetvalueInt() as bool
			mlheur_STSShowMessages.SetValueInt( false as int )
		else
			mlheur_STSShowMessages.SetValueInt( true as int )
		endif
	elseif oid == oidDebugLevel
		mlheur_STSDebugLevel.SetValueInt( value )
	elseif oid == oidAdhocSpeed && (value >= MinSpeed && value <= MaxSpeed)
		SetTimescale( value, false )
	endif
	oLog( "UpdateOption()=[]" )
endfunction

function ChangeKeyMapOption( int oid, int keycode )
	iLog( "ChangeKeyMapOption( oid=["+oid+"], keycode=["+keycode+"] )" )
	if oid == oidKeySpeedUp
		UnregisterForKey( mlheur_STSKeySpeedUp.GetValueInt() )
		mlheur_STSKeySpeedUp.SetValueInt( keycode )
	elseif oid == oidKeyShowSpeed
		UnregisterForKey( mlheur_STSKeyShowSpeed.GetValueInt() )
		mlheur_STSKeyShowSpeed.SetValueInt( keycode )
	elseif oid == oidKeySpeedDn
		UnregisterForKey( mlheur_STSKeySpeedDn.GetValueInt() )
		mlheur_STSKeySpeedDn.SetValueInt( keycode )
	elseif oid == oidKeyMeta
		UnregisterForKey( mlheur_STSKeyMeta.GetValueInt() )
		mlheur_STSKeyMeta.SetValueInt( keycode )
	endif
	if keycode >= 0 && keycode != mlheur_STSKeyMeta.GetValueInt()
		RegisterForKey( keycode )
	endif
	oLog( "ChangeKeyMapOption()=[]" )
endfunction

function ShowSpeeds()
	iLog( "ShowSpeeds()" )
	SetCursorFillMode( LEFT_TO_RIGHT )
	int i = 0
	oidNewSpeed = 0
	oidSetSpeed = new int[32]
	oidDelSpeed = new int[32]
	while i < Speeds.length
		if Speeds[i] > MaxSpeed
			i = Speeds.length
		else
			; TODO - translations
			oidSetSpeed[i] = AddSliderOption( "Timescale["+(i+1)+"]:", Speeds[i] as float )
			oidDelSpeed[i] = AddTextOption( "$STSRemove", "..." )
			oidNewSpeed = i+1
		endif
		i += 1
	endwhile
	if i > 32
		oidSetSpeed[oidNewSpeed] = AddSliderOption( "$STSNewStep", 0.0 )
	endif
	oLog( "ShowSpeeds()=[]" )
endfunction

function ShowSpeedSlider( int oid )
	iLog( "ShowSpeedSlider( oid=["+oid+"] )" )
	int IDX = -1
	int i = 0
	float StartSpeed = MinSpeed as float
	if oid == oidSetSpeed[oidNewSpeed]
		if oidNewSpeed > 0
			StartSpeed = Speeds[oidNewSpeed] - 1
		endif
	else
		while i < oidSetSpeed.length
			if oid == oidSetSpeed[i]
				IDX = i
				i = oidSetSpeed.length
			endif
			i += 1
		endwhile
		StartSpeed = Speeds[IDX]
	endif
	SetSliderDialogStartValue( StartSpeed )
	SetSliderDialogDefaultValue( StartSpeed )
	SetSliderDialogRange( MinSpeed as float, MaxSpeed as float )
	SetSliderDialogInterval( 1.0 )
	oLog( "ShowSpeedSlider()=[]" )
endfunction

function UpdateSpeed( int oid, int value )
	iLog( "UpdateSpeed( oid=["+oid+"], value=["+value+"] )" )
	int i = 0
	while i < Speeds.length
		if oid == oidDelSpeed[i] || oid == oidSetSpeed[i]
			Speeds[i] = Value
		endif
		i += 1
	endwhile
	SortSpeeds()
	oLog( "UpdateSpeed()=[]" )
endfunction

function SetTimescale( int T, bool show = true )
	iLog( "SetTimescale( T=["+T+"], show=["+show+"] )" )
	if T < MinSpeed
		T = MinSpeed
	elseif T > MaxSpeed
		T = MaxSpeed
	endif
	Timescale.SetValue( T )
	if mlheur_STSShowMessages.GetValueInt() as bool && show
		; TODO - translation
		Debug.Notification( "Set timescale to "+Timescale.GetValueInt() );
	endif
	oLog( "SetTimescale()=[]" )
endfunction

function IncTimescale()
	iLog( "IncTimescale()" )
	int T = Timescale.GetValueInt()
	int i = 0
	bool MadeChange = false;
	
	Log( "First:"\
	  + " T: "+T\
	  + " i: "+i\
	  + " Speeds[i]: "+Speeds[i]\
	  , 2 )
	while i < Speeds.length
		if Speeds[i] > MaxSpeed
			i = Speeds.length ; break, do nothing
		elseif T < Speeds[i]
			SetTimescale( Speeds[i] )
			MadeChange = true;
			i = Speeds.length ; break
		else
			i += 1
			Log( "Next:"\
			  + " T: "+T\
			  + " i: "+i\
			  + " Speeds[i]: "+Speeds[i]\
			, 2 )
		endif
	endwhile
	if ! MadeChange
		SetTimescale( Timescale.GetValueInt() ) ; just to show no-change
	endif
	oLog( "IncTimescale()=[]" )
endfunction

function DecTimescale()
	iLog( "DecTimescale()" )
	int T = Timescale.GetValueInt()
	int i = Speeds.length - 1
	bool MadeChange = false;
	
	; Skip any disabled speeds
	while Speeds[i] > MaxSpeed
		i -= 1
	endwhile
	
	Log( "First:"\
	  + " T: "+T\
	  + " i: "+i\
	  + " Speeds[i]: "+Speeds[i]\
	  , 2 )
	while i >= 0
		if T > Speeds[i]
			SetTimescale( Speeds[i] )
			MadeChange = true;
			i = -1 ; break
		else
			i -= 1
			Log( "Next:"\
			  + " T: "+T\
			  + " i: "+i\
			  + " Speeds[i]: "+Speeds[i]\
			, 2 )
		endif
	endwhile
	if ! MadeChange
		SetTimescale( Timescale.GetValueInt() ) ; just to show no-change
	endif
	oLog( "DecTimescale()=[]" )
endfunction

function InitSpeeds()
	iLog( "InitSpeeds()" )
	int i = Speeds.length
	while i
		i -= 1
		Speeds[i] = MaxSpeed+1
	endwhile
	oLog( "InitSpeeds()=[]" )
endfunction

function SortSpeeds()
	iLog( "SortSpeeds()" )
	DumpSpeeds( "Before Sort", 4 )
	int i = 0
	while i < ( Speeds.length - 1 )
		int min = i
		int j = i+1
		while j < Speeds.length
			if ( Speeds[j] < Speeds[min] )
				min = j
			endif
			j += 1
		endwhile
		Log( "Swapping "+i+" with "+min, 5 )
		int tmp = Speeds[i]
		Speeds[i] = Speeds[min]
		Speeds[min] = tmp
		i += 1
	endwhile
	i = Speeds.length
	while i
		i -= 1
		if Speeds[i] < MaxSpeed
			TopSpeedIDX = i
			i = 0
		endif
	endwhile
	DumpSpeeds( "After Sort", 3 )
	oLog( "SortSpeeds()=[]" )
endfunction

bool function IsAnyMenuOpen()
	iLog( "IsAnyMenuOpen()" )
	bool R = false
	string _m = ""
	string[] M = new string[36]
	M[0] = "BarterMenu"
	M[1] = "Book Menu"
	M[2] = "Console"
	M[3] = "Console Native UI Menu"
	M[4] = "ContainerMenu"
	M[5] = "Crafting Menu"
	M[6] = "Credits Menu"
	M[7] = "Cursor Menu"
	M[8] = "Debug Text Menu"
	M[9] = "Dialogue Menu"
	M[10] = "Fader Menu"
	M[11] = "FavoritesMenu"
	M[12] = "GiftMenu"
	M[13] = "HUD Menu - allowed"
	M[14] = "InventoryMenu"
	M[15] = "Journal Menu"
	M[16] = "Kinect Menu"
	M[17] = "LevelUp Menu"
	M[18] = "Loading Menu"
	M[19] = "Lockpicking Menu"
	M[20] = "MagicMenu"
	M[21] = "Main Menu"
	M[22] = "MapMenu"
	M[23] = "MessageBoxMenu"
	M[24] = "Mist Menu"
	M[25] = "Overlay Interaction Menu"
	M[26] = "Overlay Menu"
	M[27] = "Quantity Menu"
	M[28] = "RaceSex Menu"
	M[29] = "Sleep/Wait Menu"
	M[30] = "StatsMenu"
	M[31] = "TitleSequence Menu"
	M[32] = "Top Menu"
	M[33] = "Training Menu"
	M[34] = "Tutorial Menu"
	M[35] = "TweenMenu"
	
	int i = M.length
	while i
		i -= 1
		if UI.IsMenuOpen( M[i] )
			R = true
			_m = M[i]
			i = 0 ; break
		endif
	endwhile

	oLog( "IsAnyMenuOpen()=["+R+"], menu=["+_m+"]" )
	return R
endfunction

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Debug functions

function DumpSpeeds( string Msg = "", int Level = -1 )
	if Level < 0
		Level = 4
	endif
	int i = 0
	if Msg
		Msg = Msg + " "
	endif
	while i < Speeds.length
		Log( Msg + "Speeds["+i+"] = "+Speeds[i], Level );
		i += 1
	endwhile
endfunction

function iLog( string Msg, int Level = -1 )
	if Level < 0
		Level = 4
	endif
	Log( "++"+Msg, Level )
	_indent += 1
endfunction

function oLog( string Msg, int Level = -1 )
	if Level < 0
		Level = 4
	endif
	_indent -= 1
	if _indent < 0
		_indent = 0
	endif
	Log( "--"+Msg, Level )
endfunction

function Log( string Msg, int Level = 0 )
	if Level > mlheur_STSDebugLevel.GetValueInt()
		return
	endif
	string indent = "";
	int i = _indent;
	while i
		i-=1
		indent += "  "
	endwhile
	Debug.trace( "STS::["+Level+"]"+indent+Msg )
endfunction