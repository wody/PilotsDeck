---@diagnostic disable: undefined-global

ipc.sleep(30000) --Give the QW787 init process some time (seems to trigger Ind Lights with RAAS and Auto-Scripts?!)

local syncPilotsDeck = true			--Generates/Writes the Offset Values used in the StreamDeck Profiles to display Baro, MCP Displays and Lights

local syncCabin = false				--Turn the Cabin Lights on or off if the Cabin/Utility Buttton in the Overhead is toggled
local syncBrake = false				--Sync the Parking Brake to the State of the Joystick Button (TCA and equivalents). Change Joystick Number and Button Number for the two Variables accordingly!
local brakeJoystick = 1				--The Joystick Number as known to FSUIPC
local brakeButton = 19				--The Button Number as known to FSUIPC
local syncFD = false				--Sync the FO's FD to the Captains

local syncGSX = false				--Sync to Ground-Service Animations/Handling - open/close doors according to the Services currently performed by GSX. The GSX_AUTO Script QualityWings2GSX need to be running for that!
local syncChocksAndPower = false	--Automatically set/remove Chocks and External Power according to the Jetway Operating State from GSX (When Jetway connected -> Chocks set / Ext Power available). Only Works when syncGSX is also true.
local operateJetways = false		--Operate the Jetway(s) automatically when arriving/departing (syncGSX has to be enabled)

-- 04E0-0537	88		Project Magenta
-- 66C0-66FF	64		General Use
-- 5400-57FF	1024	PMDG CDU0 / Project Magenta

function QW787_SYNC()
		QWsyncButtons()
		if syncPilotsDeck then
			QWreadBARO()		--0x5408 STR,4
			QWreadFCU()			--SPD: 0x540C STR,9 | HDG: 0x5415 STR,8 | ALT: 0x541D STR,7 | VS: 0x5424 STR,9 | Mode+ALT+VS: 0x542D STR,17
			QWUpdateButtonLt()	--0x543E UB,1 .. 0x5445
		end
		QWsyncGSX()
end

event.timer(250, "QW787_SYNC")
ipc.log("QualityWings Sync active")

-----------------------------------------------------------
-----------------------------------------------------------
-- QW787

function QWsyncButtons()
	-- Brake
	if syncBrake and ipc.readLvar("QW_OH_TOWER_PWR_Button") == 1 or ipc.readLvar("QW_OH_ELE_BAT_Button") == 1 then
		local parkbrake = ipc.readUW(0x0BC8) == 32767
		local brakebtn = ipc.testbutton(brakeJoystick, brakeButton)

		if not parkbrake and brakebtn then
			ipc.control(65752)
		elseif parkbrake and not brakebtn then
			ipc.control(65752)
		end
	end

	-- Cabin Lights
	if syncCabin then
		local LightOn = ipc.readLvar("QW_OH_CAB_UTIL_Button") == 1

		if not LightOn then
			ipc.writeLvar("QW_Cabin_Light_OnOff", 0)
		else
			ipc.writeLvar("QW_Cabin_Light_OnOff", 1)
			ipc.writeLvar("QW_Cabin_Light", 20)
			ipc.writeLvar("QW_Cabin_Brightness", 20)
		end
	end

	-- Flight Director
	if syncFD then
		local directorL = ipc.readLvar("QW_MCP_L_FD_Switch")
		local directorR = ipc.readLvar("QW_MCP_R_FD_Switch")
		if directorL ~= directorR then
			ipc.writeLvar("QW_MCP_R_FD_Switch", directorL)
		end
	end

	-- External Power
	if syncChocksAndPower and syncGSX and ipc.readLvar("EXT_POWER_AVAIL") == 0 and ipc.readLvar("QW_OH_FWDEXTPWR_LEFT_Button") == 1 then
		ipc.writeLvar("QW_OH_FWDEXTPWR_LEFT_Button", 0)
	end
end

local QW_DOOR_L1_OP = false
local QW_DOOR_L2_OP = false
local QW_DOOR_L4_OP = false
local QW_DOOR_R2_OP = false
local QW_DOOR_R4_OP = false
local QW_CARGO_FWD_OP = false
local QW_CARGO_AFT_OP = false

function QWtoggleDoor(lvar, close)
	if close ~= nil or ipc.readLvar(lvar) == 1 then
		ipc.writeLvar(lvar, 0)
	else
		ipc.writeLvar(lvar, 1)
	end
end

function QWoperateDoor(triggerVar, doorVar, opstate, controlParam)
	local trigger = ipc.readLvar(triggerVar)
	if trigger == 1 and not opstate then
		ipc.log("QW787_SYNC: Trigger for Door " .. doorVar .. " detected - operating Door.")
		opstate = true
		if controlParam ~= nil then
			ipc.control(66389, controlParam)
		end
		QWtoggleDoor(doorVar)
	elseif trigger == 0 and opstate then
		ipc.log("QW787_SYNC: Resetting operating State for " .. doorVar)
		opstate = false
	end

	return opstate
end

local QW_CARGO_TICKS = 0
local QW_GSX_JETWAYS_REQUESTED = false
local GSX_AUTO_LAST = 0
function QWsyncGSX()
	if not syncGSX or ipc.readSW(0x0366) == 0 or ipc.readLvar("GSX_AUTO_SERVICE_STATE") == nil then
		return
	end
	local cycle_state = ipc.readLvar("GSX_AUTO_SERVICE_STATE")

	-- EXT PWR && CHOCKS (Sync disabled with Tow Power ON)
	if syncChocksAndPower and ipc.readLvar("QW_OH_TOWER_PWR_Button") == 0 then
		local GSX_AUTO_CONNECTED = ipc.readLvar("GSX_AUTO_CONNECTED")
		if GSX_AUTO_LAST ~= GSX_AUTO_CONNECTED and GSX_AUTO_CONNECTED == 1 then
			ipc.writeLvar("EXT_POWER_AVAIL", 1)
			ipc.writeLvar("QW_WheelChocks",1)
			GSX_AUTO_LAST = GSX_AUTO_CONNECTED
			ipc.log("QW787_SYNC: ExtPwr/Chocks are set.")
		elseif GSX_AUTO_LAST ~= GSX_AUTO_CONNECTED and GSX_AUTO_CONNECTED == 0 then
			ipc.writeLvar("EXT_POWER_AVAIL", 0)
			ipc.writeLvar("QW_WheelChocks",0)
			GSX_AUTO_LAST = GSX_AUTO_CONNECTED
			ipc.log("QW787_SYNC: ExtPwr/Chocks are removed.")
		end
	end

	local GSX_BOARD_STATE = ipc.readLvar("FSDT_GSX_BOARDING_STATE")
	local GSX_DEBOARD_STATE = ipc.readLvar("FSDT_GSX_DEBOARDING_STATE")

	-- PAX/CARGO	Open for (De)Boarding when requested by GSX
	if GSX_BOARD_STATE >= 4 or GSX_DEBOARD_STATE >= 4 then
		QW_DOOR_L1_OP = QWoperateDoor("FSDT_GSX_AIRCRAFT_EXIT_1_TOGGLE", "DoorL1", QW_DOOR_L1_OP, 1)

		QW_DOOR_L2_OP = QWoperateDoor("FSDT_GSX_AIRCRAFT_EXIT_2_TOGGLE", "DoorL2", QW_DOOR_L2_OP, 2)

		QW_DOOR_L4_OP = QWoperateDoor("FSDT_GSX_AIRCRAFT_EXIT_4_TOGGLE", "DoorL4", QW_DOOR_L4_OP)

		QW_CARGO_FWD_OP = QWoperateDoor("FSDT_GSX_AIRCRAFT_CARGO_1_TOGGLE", "QW_CargoDoor_Fwd", QW_CARGO_FWD_OP, 4)

		QW_CARGO_AFT_OP = QWoperateDoor("FSDT_GSX_AIRCRAFT_CARGO_2_TOGGLE", "QW_CargoDoor_Aft", QW_CARGO_AFT_OP)
	end

	-- PAX		Close after Boarding
	if GSX_BOARD_STATE == 6 and GSX_DEBOARD_STATE ~= 5 then
		if ipc.readLvar("DoorL1") == 1 then
			ipc.log("QW787_SYNC: Close L1 Door afer Boarding.")
			ipc.control(66389, 1) -- L1
			QWtoggleDoor("DoorL1", true)
		end

		if ipc.readLvar("DoorL2") == 1  then
			ipc.log("QW787_SYNC: Close L2 Door afer Boarding.")
			ipc.control(66389, 2) -- L2
			QWtoggleDoor("DoorL2", true)
		end

		if ipc.readLvar("DoorL4") == 1 then
			ipc.log("QW787_SYNC: Close L4 Door afer Boarding.")
			QWtoggleDoor("DoorL4", true)
		end
	end

	-- CARGO		Close after De/Boarding
	if QW_CARGO_TICKS == 0 and ((cycle_state == 2 and ipc.readLvar("FSDT_GSX_BOARDING_CARGO_PERCENT") == 100) or (cycle_state == 7 and ipc.readLvar("FSDT_GSX_DEBOARDING_CARGO_PERCENT") == 100)) then
		if ipc.readLvar("QW_CargoDoor_Fwd") == 1 or ipc.readLvar("QW_CargoDoor_Aft") == 1 then
			QW_CARGO_TICKS = 1
		end
	end
	if QW_CARGO_TICKS == 55 then
		ipc.log("QW787_SYNC: Close Cargo Doors afer (Un)Loading.")
		if ipc.readLvar("QW_CargoDoor_Fwd") == 1 then
			ipc.control(66389, 4) -- CARGO FWD
			QWtoggleDoor("QW_CargoDoor_Fwd")
		end

		if ipc.readLvar("QW_CargoDoor_Aft") == 1 then
			QWtoggleDoor("QW_CargoDoor_Aft")
		end
		QW_CARGO_TICKS = 0
	elseif QW_CARGO_TICKS >= 1 then
		QW_CARGO_TICKS = QW_CARGO_TICKS + 1
	end

	-- CARGO		Sync Light
	local qwFwdLight = ipc.readLvar("QW_CargoLight_fwd") == 1
	local qwFwdDoor = ipc.readLvar("QW_CargoDoor_Fwd") == 1
	if qwFwdDoor and not qwFwdLight then
		ipc.writeLvar("QW_CargoLight_fwd", 1)
	elseif not qwFwdDoor and qwFwdLight then
		ipc.writeLvar("QW_CargoLight_fwd", 0)
	end

	local qwAftLight = ipc.readLvar("QW_CargoLight_aft") == 1
	local qwAftDoor = ipc.readLvar("QW_CargoDoor_Aft") == 1
	if qwAftDoor and not qwAftLight then
		ipc.writeLvar("QW_CargoLight_aft", 1)
	elseif not qwAftDoor and qwAftLight then
		ipc.writeLvar("QW_CargoLight_aft", 0)
	end

	-- SERVICE		Open/Close for Catering as requested by GSX
	if ipc.readLvar("FSDT_GSX_CATERING_STATE") >= 4 then
		QW_DOOR_R2_OP = QWoperateDoor("FSDT_GSX_AIRCRAFT_SERVICE_1_TOGGLE", "DoorR2", QW_DOOR_R2_OP)

		QW_DOOR_R4_OP = QWoperateDoor("FSDT_GSX_AIRCRAFT_SERVICE_2_TOGGLE", "DoorR4", QW_DOOR_R4_OP)
	end

	-- JETWAYS
	if not operateJetways then
		return
	end
	local beacon = logic.And(ipc.readUW(0x0D0C), 2)
	local connected = ipc.readLvar("GSX_AUTO_CONNECTED") == 1

	-- when in Push State, Beacon ON, Park Brake SET and Ext Pwr OFF -> toggle Jetways
	if cycle_state == 3 and not QW_GSX_JETWAYS_REQUESTED and beacon ~= 0 and connected and ipc.readUW(0x0BC8) == 32767 and ipc.readLvar("QW_OH_FWDEXTPWR_LEFT_Button") == 0 then
		QW_GSX_JETWAYS_REQUESTED = true
		ipc.log("QW787_SYNC: Departing - requesting Disconnect")
		ipc.writeLvar("GSX_AUTO_CONNECT_REQUESTED", 1)
	elseif cycle_state ~=3 and cycle_state ~=7 and QW_GSX_JETWAYS_REQUESTED then
		QW_GSX_JETWAYS_REQUESTED = false
	end

	-- when in Deboard State, Engines Stopped and Beacon OFF -> toggle Jetways (if not already requested)
	if cycle_state == 7 and not QW_GSX_JETWAYS_REQUESTED and not connected and ipc.readLvar("FSDT_VAR_EnginesStopped") == 1 and beacon == 0 then
			QW_GSX_JETWAYS_REQUESTED = true
			ipc.log("QW787_SYNC: Arriving - requesting Connect and Deboard")
			ipc.writeLvar("GSX_AUTO_CONNECT_REQUESTED", 1)
			ipc.writeLvar("GSX_AUTO_DEBOARD_REQUESTED", 1)
	elseif cycle_state == 7 and QW_GSX_JETWAYS_REQUESTED and connected then
		QW_GSX_JETWAYS_REQUESTED = false
	end
end

function QWreadBARO()
	local unitMode = ipc.readLvar("QW_MCP_L_BAROSET_Knob")
	local pressure = ipc.readUW(0x0330)
	local offset = 0x5408

	if pressure ~= 16211 then
		if unitMode == 0 then
			ipc.writeSTR(offset, string.format("%.0f", pressure * 0.1845585973546601), 4)
		else
			ipc.writeSTR(offset, string.format("%.0f", pressure * 0.0625), 4)
		end
	else
		ipc.writeSTR(offset, "STD", 4)
	end
end

function QWreadFCU()		--SPD: 0x540C STR,9 | HDG: 0x5415 STR,8 | ALT: 0x541D STR,7 | VS: 0x5424 STR,9 | Mode+ALT+VS: 0x542D STR,17 (-> 0x543E)
	local vert_mode = ipc.readLvar("ap_vert_mode")

	--------speed
	local isMachModeOn = ipc.readLvar("qw_mach_status") == 1
	local isVnav = vert_mode == 6 or vert_mode == 5

	local spd = " "
	if not isVnav then
		if isMachModeOn then
			spd = "MACH\n" .. string.format("%.2f", ipc.readUD(0x07E8) * 0.0000152587890625)
		else
			spd = "IAS\n" .. ipc.readUW(0x07E2)
		end
	end

	ipc.writeSTR(0x540C, spd, 9)

	--------hdg
	local hdg = "HDG\n"
	local isTrkModeOn = ipc.readLvar("QW_MCP_HDG_TRK_Status") == 1
	if isTrkModeOn then
		hdg = "TRK\n"
	end

	local hdgval = ipc.readUW(0x07CC) * 0.0054931640625
	hdgval = string.format("%0.f", hdgval)
	if hdgval == "0" then
		hdgval = "360"
	end

	hdg = hdg .. string.format("%03.f", hdgval)

	ipc.writeSTR(0x5415, hdg, 8)

	--------alt
	local alt = ipc.readUD(0x07D4) * 0.0000500616455078125
	alt = string.format("%0.f", alt)

	if ipc.readLvar("QW_MCP_ALT_AUTO_Knob") == 0 then
		if string.len(alt) == 5 then
			alt = string.sub(alt, 1, 2) .. " " .. string.sub(alt, 3, 5)
		elseif string.len(alt) == 4 then
			alt = string.sub(alt, 1, 1) .. " " .. string.sub(alt, 2, 4)
		end
	end

	ipc.writeSTR(0x541D, alt, 7)

	-----vs
	local vs = " "
	local vsEnabled = vert_mode == 2 or vert_mode == 3


	if vsEnabled then
		vs = "V/S\n"
		local vsft = ipc.readSW(0x07F2)
		if vsft >= 0 then
			vs = vs .. "+" .. string.format("%03d", vsft)
		else
			vs =  vs .. string.format("%03d", vsft)
		end
	end

	ipc.writeSTR(0x5424, vs, 9)

	--- alt + vs
	if vs ~= " " then
		ipc.writeSTR(0x542D, alt .. "\n" .. vs, 17)
	else
		ipc.writeSTR(0x542D, alt, 17)
	end
end

function QWUpdateButtonLt()
	local vert_mode = ipc.readLvar("ap_vert_mode")
	local vert_mode_arm = ipc.readLvar("ap_vert_mode_armed")
	local lat_mode = ipc.readLvar("ap_lat_mode")
	local lat_mode_arm = ipc.readLvar("ap_lat_mode_armed")

	--vnav
	if vert_mode == 5 or vert_mode == 6 or vert_mode_arm == 5 or vert_mode_arm == 6 then
		ipc.writeUB(0x543E,1)
	else
		ipc.writeUB(0x543E,0)
	end

	--flch
	if vert_mode == 4 or vert_mode_arm == 4 then
		ipc.writeUB(0x543F,1)
	else
		ipc.writeUB(0x543F,0)
	end

	--vs/fpa
	if vert_mode == 2 or vert_mode == 3 or vert_mode_arm == 2 or vert_mode_arm == 3 then
		ipc.writeUB(0x5440,1)
	else
		ipc.writeUB(0x5440,0)
	end

	--alt hold
	if vert_mode == 1 or vert_mode_arm == 1 then
		ipc.writeUB(0x5441,1)
	else
		ipc.writeUB(0x5441,0)
	end

	--app
	if vert_mode == 10 or vert_mode_arm == 10 then
		ipc.writeUB(0x5442,1)
	else
		ipc.writeUB(0x5442,0)
	end

	--lnav
	if lat_mode == 6 or lat_mode_arm == 6 then
		ipc.writeUB(0x5443,1)
	else
		ipc.writeUB(0x5443,0)
	end

	--hdg hold
	if lat_mode == 2 or lat_mode == 4 or lat_mode_arm == 2 or lat_mode_arm == 4 then
		ipc.writeUB(0x5444,1)
	else
		ipc.writeUB(0x5444,0)
	end

	--loc/fac
	if (lat_mode == 7 or lat_mode_arm == 7) and (vert_mode ~= 10 and vert_mode_arm ~= 10) then
		ipc.writeUB(0x5445,1)
	else
		ipc.writeUB(0x5445,0)
	end
end