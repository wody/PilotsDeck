﻿// Implement settingsModel for the Action
var settingsModel = {
	DefaultImage: "Images/ValueFrame.png",
	ErrorImage: "Images/ValueError.png",
	Address: "",
	AddressAction: "",
	ActionType: 0,
	OnState: "",
	OffState: "",
	DecodeBCD: false,
	Scalar: 1,
    Format: "",
    HasIndication: false,
	IndicationHideValue: false,
	IndicationUseColor: false,
	IndicationColor: "#ffffff",
    IndicationImage: "Images/ValueFault.png",
    IndicationValue: "0",
    FontInherit: true,
	FontName: "Arial",
	FontSize: 10,
	FontStyle: 0,
	FontColor: '#ffffff',
	RectCoord: "11; 23; 48; 40"
};

// Fill Select Boxes for Actions here
function fillSelectBoxes() {
	if (ImageFiles && ImageFiles != "") {
		fillImageSelectBox(ImageFiles, 'DefaultImage', settingsModel.DefaultImage);
		fillImageSelectBox(ImageFiles, 'ErrorImage', settingsModel.ErrorImage);
		fillImageSelectBox(ImageFiles, 'IndicationImage', settingsModel.IndicationImage);
	}
	if (FontNames && FontNames != "") {
		fillFontSelectBox(FontNames, 'FontName', settingsModel.FontName);
	}
	if (FontStyles && FontStyles != "") {
		fillTypeSelectBox(FontStyles, 'FontStyle', settingsModel.FontStyle);
	}
	if (ActionTypes && ActionTypes != "") {
		fillTypeSelectBox(ActionTypes, 'ActionType', settingsModel.ActionType);
	}
}

// Show/Hide elements on Form (required function)
function updateForm() {
	//PATTERN
	setPattern('Address', 5);
	setPattern('AddressAction', settingsModel.ActionType);

	//On/Off States
	if (settingsModel.ActionType == 0) { //macro
		toggleConfigItem(false, 'OnState');
		toggleConfigItem(false, 'OffState');
	}
	else if (settingsModel.ActionType == 1) { //script
		toggleConfigItem(false, 'OnState');
		toggleConfigItem(false, 'OffState');
	}
	else if (settingsModel.ActionType == 2) { //control
		toggleConfigItem(false, 'OnState');
		toggleConfigItem(false, 'OffState');
	}
	else if (settingsModel.ActionType == 3) { //lvar
		toggleConfigItem(true, 'OnState');
		toggleConfigItem(true, 'OffState');
	}
	else if (settingsModel.ActionType == 4) { //offset
		toggleConfigItem(true, 'OnState');
		toggleConfigItem(true, 'OffState');
	}
	else {
		toggleConfigItem(false, 'OnState');
		toggleConfigItem(false, 'OffState');
	}

	//INDICATION
	toggleConfigItem(settingsModel.HasIndication, 'IndicationHideValue');
	toggleConfigItem(settingsModel.HasIndication, 'IndicationImage');
	toggleConfigItem(settingsModel.HasIndication && !settingsModel.IndicationHideValue, 'IndicationUseColor');
	toggleConfigItem(settingsModel.HasIndication && !settingsModel.IndicationHideValue && settingsModel.IndicationUseColor, 'IndicationColor');
	toggleConfigItem(settingsModel.HasIndication, 'IndicationValue');

	//FONT
	toggleConfigItem(!settingsModel.FontInherit, 'FontName');
	toggleConfigItem(!settingsModel.FontInherit, 'FontSize');
	toggleConfigItem(!settingsModel.FontInherit, 'FontStyle');
	toggleConfigItem(!settingsModel.FontInherit, 'FontColor');
}
