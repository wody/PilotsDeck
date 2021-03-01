﻿// Implement settingsModel for the Action
var settingsModel = {
	EnableSwitching: false,
	ProfilesInstalled: false,
	MappingsJson: ""
},
	installationRequested = 0;

//var installationRequested = false;

// Fill Select Boxes for Actions here
function fillSelectBoxes() {

}

// Show/Hide elements on Form (required function)
function updateForm() {
	installationRequested++;
	if (!settingsModel.ProfilesInstalled && installationRequested == 2) {
		var checkbox = document.getElementById('ProfilesInstalled');
		const evt = new Event('change');
		checkbox.dispatchEvent(evt);
		installationRequested = true;
    }

	if (!settingsModel.MappingsJson)
		return;
	var deviceMappings = JSON.parse(settingsModel.MappingsJson);
	var divProfiles = document.getElementById('divWrapper');

	if (deviceMappings && deviceMappings.length) {
		
		for (var d = 0; d < deviceMappings.length; d++) {
			if (!document.getElementById('hdg_' + d) && deviceMappings[d].Profiles && deviceMappings[d].Profiles.length) {
				//HEADING
				var divHeading = document.createElement('div');
				divHeading.setAttribute("class", "sdpi-heading");
				divHeading.id = "hdg_" + d;
				divHeading.innerText = "Profiles for " + deviceMappings[d].Name;
				divProfiles.appendChild(divHeading);

				//USE DEFAULT
				var divUseDefaultConf = document.createElement('div');
				divUseDefaultConf.id = "Config_UseDefault_" + d;
				divUseDefaultConf.setAttribute("type", "checkbox");
				divUseDefaultConf.setAttribute("class", "sdpi-item");

				var divUseDefaultLabel = document.createElement('div');
				divUseDefaultLabel.id = "lblUseDefault_" + d;
				divUseDefaultLabel.setAttribute("class", "spdi-item-label");
				divUseDefaultLabel.innerText = "Use Default";
				divUseDefaultConf.appendChild(divUseDefaultLabel);

				var divUseDefaultInput = document.createElement('input');
				divUseDefaultInput.id = "UseDefault_" + d;
				divUseDefaultInput.setAttribute("type", "checkbox");
				divUseDefaultInput.setAttribute("class", "spdi-item-value");
				divUseDefaultInput.checked = deviceMappings[d].UseDefault;
				divUseDefaultInput.setAttribute("onchange", "setJsonDeviceSettings(event.target.checked, 'UseDefault', " + d + ")");
				divUseDefaultConf.appendChild(divUseDefaultInput);

				var labelUseDefaultLabel = document.createElement('label');
				labelUseDefaultLabel.setAttribute("for", "UseDefault_" + d);
				labelUseDefaultLabel.appendChild(document.createElement('span'));
				divUseDefaultConf.appendChild(labelUseDefaultLabel);
				
				divProfiles.appendChild(divUseDefaultConf);

				//DEFAULT PROFILE
				var divDefaultProfileConf = document.createElement('div');
				divDefaultProfileConf.id = "Config_DefaultProfile_" + d;
				divDefaultProfileConf.setAttribute("class", "spdi-item");

				var divDefaultProfileLabel = document.createElement('div');
				divDefaultProfileLabel.id = "lblDefaultProfile_" + d;
				divDefaultProfileLabel.setAttribute("class", "spdi-item-label");
				divDefaultProfileLabel.innerText = "Default Name";
				divDefaultProfileConf.appendChild(divDefaultProfileLabel);
				
				var divDefaultProfileInput = document.createElement('input');
				divDefaultProfileInput.id = "DefaultProfile_" + d;
				divDefaultProfileInput.setAttribute("type", "text");
				divDefaultProfileInput.setAttribute("class", "spdi-item-value");
				divDefaultProfileInput.value = deviceMappings[d].DefaultProfile;
				divDefaultProfileInput.setAttribute("onchange", "setJsonDeviceSettings(event.target.value, 'DefaultProfile', " + d + ")");
				divDefaultProfileConf.appendChild(divDefaultProfileInput);

				divProfiles.appendChild(divDefaultProfileConf);
				divProfiles.appendChild(document.createElement('br'));
				divProfiles.appendChild(document.createElement('br'));

				for (var p = 0; p < deviceMappings[d].Profiles.length; p++) {
					var divOuter = document.createElement('div');
					divOuter.setAttribute("class", "spdi-item");
					divOuter.id = "Config_Mappings_" + d + "_" + p;

					var divLabel = document.createElement('div');
					divLabel.setAttribute("class", "spdi-item-label");
					divLabel.id = "lblMappings_" + d + "_" + p;
					divLabel.innerHTML = deviceMappings[d].Profiles[p].Name;

					var input = document.createElement('input');
					input.setAttribute("class", "spdi-item-value");
					input.id = "Mappings_" + d + "_" + p;
					input.type = "text";
					input.value = deviceMappings[d].Profiles[p].Mappings;
					input.setAttribute("onchange", "setJsonDeviceProfileSettings(event.target.value, " + d + ", " + p + ")");
					
					divOuter.appendChild(divLabel);
					divOuter.appendChild(input);

					divProfiles.appendChild(divOuter);
				}
				if (d < deviceMappings.length - 1) {
					divProfiles.appendChild(document.createElement('br'));
					divProfiles.appendChild(document.createElement('br'));
				}
			}
			else if (document.getElementById('hdg_' + d) && deviceMappings[d].Profiles && deviceMappings[d].Profiles.length) {
				document.getElementById("UseDefault_" + d).checked = deviceMappings[d].UseDefault;
				document.getElementById("DefaultProfile_" + d).value = deviceMappings[d].DefaultProfile;
				for (var p = 0; p < deviceMappings[d].Profiles.length; p++) {
					document.getElementById("Mappings_" + d + "_" + p).value = deviceMappings[d].Profiles[p].Mappings;
				}
            }
        }
	}
}

const setJsonDeviceSettings = (value, param, idxDev) => {
	var deviceMappings = JSON.parse(settingsModel.MappingsJson);
	deviceMappings[parseInt(idxDev)][param] = value;
	var jsonStr = JSON.stringify(deviceMappings);
	setSettings(jsonStr, "MappingsJson");
}

const setJsonDeviceProfileSettings = (value, idxDev, idxProf) => {
	var deviceMappings = JSON.parse(settingsModel.MappingsJson);
	deviceMappings[parseInt(idxDev)].Profiles[parseInt(idxProf)].Mappings = value;
	var jsonStr = JSON.stringify(deviceMappings);
	setSettings(jsonStr, "MappingsJson");
}