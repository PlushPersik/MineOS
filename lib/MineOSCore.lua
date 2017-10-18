
require("advancedLua")
local component = require("component")
local buffer = require("doubleBuffering")
local filesystem = require("filesystem")
local unicode = require("unicode")
local MineOSPaths = require("MineOSPaths")

----------------------------------------------------------------------------------------------------------------

local MineOSCore = {}
MineOSCore.localization = {}

----------------------------------------------------------------------------------------------------------------

function MineOSCore.getCurrentScriptDirectory()
	return filesystem.path(getCurrentScript())
end

function MineOSCore.getCurrentApplicationResourcesDirectory() 
	return MineOSCore.getCurrentScriptDirectory() .. "/Resources/"
end

function MineOSCore.getLocalization(pathToLocalizationFolder)
	local localizationFileName = pathToLocalizationFolder .. MineOSCore.properties.language .. ".lang"
	if filesystem.exists(localizationFileName) then
		return table.fromFile(localizationFileName)
	else
		error("Localization file \"" .. localizationFileName .. "\" doesn't exists")
	end
end

function MineOSCore.getCurrentApplicationLocalization()
	return MineOSCore.getLocalization(MineOSCore.getCurrentApplicationResourcesDirectory() .. "Localization/")	
end

-----------------------------------------------------------------------------------------------------------------------------------

function MineOSCore.createShortcut(where, forWhat)
	filesystem.makeDirectory(filesystem.path(where))
	local file = io.open(where, "w")
	file:write(forWhat)
	file:close()
end

function MineOSCore.readShortcut(path)
	local file = io.open(path, "r")
	local data = file:read("*a")
	file:close()
	
	return data
end

-----------------------------------------------------------------------------------------------------------------------------------

function MineOSCore.saveProperties()
	table.toFile(MineOSPaths.properties, MineOSCore.properties, true)
end

function MineOSCore.loadPropeties()
	local saveLater = false

	if filesystem.exists(MineOSPaths.properties) then
		MineOSCore.properties = table.fromFile(MineOSPaths.properties)
	else
		MineOSCore.properties = {}

		MineOSCore.associateExtension(".pic", MineOSPaths.applications .. "/Photoshop.app/Main.lua", MineOSPaths.icons .. "/Image.pic", MineOSPaths.extensionAssociations .. "Pic/ContextMenu.lua")
		MineOSCore.associateExtension(".txt", MineOSPaths.editor, MineOSPaths.icons .. "/Text.pic")
		MineOSCore.associateExtension(".cfg", MineOSPaths.editor, MineOSPaths.icons .. "/Config.pic")
		MineOSCore.associateExtension(".3dm", MineOSPaths.applications .. "/3DPrint.app/Main.lua", MineOSPaths.icons .. "/3DModel.pic")

		MineOSCore.associateExtension("script", MineOSPaths.extensionAssociations .. "Lua/Launcher.lua", MineOSPaths.icons .. "/Script.pic", MineOSPaths.extensionAssociations .. "Lua/ContextMenu.lua")
		MineOSCore.associateExtension(".lua", MineOSPaths.extensionAssociations .. "Lua/Launcher.lua", MineOSPaths.icons .. "/Lua.pic", MineOSPaths.extensionAssociations .. "Lua/ContextMenu.lua")
		MineOSCore.associateExtension(".pkg", MineOSPaths.extensionAssociations .. "Pkg/Launcher.lua", MineOSPaths.icons .. "/Archive.pic")

		saveLater = true
	end

	local defaultValues = {
		language = "Russian",
		showHelpOnApplicationStart = true,
		transparencyEnabled = true,
		showApplicationIcons = true,
		horizontalSpaceBetweenIcons = 1,
		verticalSpaceBetweenIcons = 1,
		showExtension = false,
		backgroundColor = 0x1E1E1E,
		wallpaper = MineOSPaths.pictures .. "TyanSunset.pic",
		wallpaperMode = 1,
		screensaver = "Matrix",
		screensaverDelay = 20,
		timezone = 3,		
		dockShortcuts = {
			MineOSPaths.applications .. "AppMarket.app/",
			MineOSPaths.applications .. "MineCode IDE.app/",
			MineOSPaths.applications .. "Finder.app/",
			MineOSPaths.applications .. "Photoshop.app/",
			MineOSPaths.applications .. "Control.app/",
		},
		network = {
			users = {},
			enabled = true,
			signalStrength = 512,
		},
	}

	for key, value in pairs(defaultValues) do
		if MineOSCore.properties[key] == nil then
			MineOSCore.properties[key] = value
			saveLater = true
		end
	end

	if saveLater then
		MineOSCore.saveProperties()
	end
end

-----------------------------------------------------------------------------------------------------------------------------------

function MineOSCore.associateExtensionLauncher(extension, pathToLauncher)
	MineOSCore.properties.extensionAssociations = MineOSCore.properties.extensionAssociations or {}
	MineOSCore.properties.extensionAssociations[extension] = MineOSCore.properties.extensionAssociations[extension] or {}
	MineOSCore.properties.extensionAssociations[extension].launcher = pathToLauncher
end

function MineOSCore.associateExtensionIcon(extension, pathToIcon)
	MineOSCore.properties.extensionAssociations[extension] = MineOSCore.properties.extensionAssociations[extension] or {}
	MineOSCore.properties.extensionAssociations[extension].icon = pathToIcon
end

function MineOSCore.associateExtensionContextMenu(extension, pathToContextMenu)
	MineOSCore.properties.extensionAssociations[extension] = MineOSCore.properties.extensionAssociations[extension] or {}
	MineOSCore.properties.extensionAssociations[extension].contextMenu = pathToContextMenu
end

function MineOSCore.associateExtension(extension, pathToLauncher, pathToIcon, pathToContextMenu)
	MineOSCore.associateExtensionLauncher(extension, pathToLauncher)
	MineOSCore.associateExtensionIcon(extension, pathToIcon)
	MineOSCore.associateExtensionContextMenu(extension, pathToContextMenu)
end

function MineOSCore.associationsExtensionAutomatically()
	local path, extension = MineOSPaths.extensionAssociations
	for file in filesystem.list(path) do
		if filesystem.isDirectory(path .. file) then
			extension = "." .. unicode.sub(file, 1, -2)

			if filesystem.exists(path .. file .. "ContextMenu.lua") then
				MineOSCore.associateExtensionContextMenu(extension, path .. file .. "Context menu.lua")
			end

			if filesystem.exists(path .. file .. "Launcher.lua") then
				MineOSCore.associateExtensionLauncher(extension, path .. file .. "Launcher.lua")
			end
		end
	end
end

-----------------------------------------------------------------------------------------------------------------------------------

--Функция парсинга Lua-сообщения об ошибке. Конвертирует из строки в массив.
function MineOSCore.parseErrorMessage(error, indentationWidth)
	local parsedError = {}

	--Замена /r/n и табсов
	error = string.gsub(error, "\r\n", "\n")
	error = string.gsub(error, "	", string.rep(" ", indentationWidth or 4))

	--Удаление энтеров
	local searchFrom, starting, ending = 1
	for i = 1, unicode.len(error) do
		starting, ending = string.find(error, "\n", searchFrom)
		if starting then
			table.insert(parsedError, unicode.sub(error, searchFrom, starting - 1))
			searchFrom = ending + 1
		else
			break
		end
	end

	--На всякий случай, если сообщение об ошибке без энтеров вообще, т.е. однострочное
	if #parsedError == 0 then table.insert(parsedError, error) end

	return parsedError
end

function MineOSCore.call(method, ...)
	local args = {...}
	local function launchMethod()
		method(table.unpack(args))
	end

	local function tracebackMethod(xpcallTraceback)
		local traceback, info, firstMatch = tostring(xpcallTraceback) .. "\n" .. debug.traceback()
		for runLevel = 0, math.huge do
			info = debug.getinfo(runLevel)
			if info then
				if (info.what == "main" or info.what == "Lua") and info.source ~= "=machine" then
					if firstMatch then
						return {
							path = info.source:sub(2, -1),
							line = info.currentline,
							traceback = traceback
						}
					else
						firstMatch = true
					end
				end
			else
				error("Failed to get debug info for runlevel " .. runLevel)
			end
		end
	end
	
	local xpcallSuccess, xpcallReason = xpcall(launchMethod, tracebackMethod)
	if type(xpcallReason) == "string" or type(xpcallReason) == "nil" then xpcallReason = {path = "/lib/MineOSCore.lua", line = 1, traceback = "MineOSCore fatal error: " .. tostring(xpcallReason)} end
	if not xpcallSuccess and not xpcallReason.traceback:match("^table") and not xpcallReason.traceback:match("interrupted") then
		return false, xpcallReason.path, xpcallReason.line, xpcallReason.traceback
	end

	return true
end

function MineOSCore.safeLaunch(path, ...)
	path = path:gsub("/+", "/") 
	MineOSCore.lastLaunchPath = path

	local oldResolutionWidth, oldResolutionHeight = buffer.width, buffer.height
	local finalSuccess, finalPath, finalLine, finalTraceback = true
	
	if filesystem.exists(path) then
		local loadSuccess, loadReason = loadfile("/" .. path)
		if loadSuccess then
			local success, path, line, traceback = MineOSCore.call(loadSuccess, ...)
			if not success then
				finalSuccess, finalPath, finalLine, finalTraceback = false, path, line, traceback
			end
		else
			local match = string.match(loadReason, ":(%d+)%:")
			finalSuccess, finalPath, finalLine, finalTraceback = false, path, tonumber(match) or 1, loadReason
		end
	else
		require("GUI").error("Failed to safely launch file that doesn't exists: \"" .. path .. "\"")
	end

	component.screen.setPrecise(false)
	buffer.setResolution(oldResolutionWidth, oldResolutionHeight)

	return finalSuccess, finalPath, finalLine, finalTraceback
end

-----------------------------------------------------------------------------------------------------------------------------------

MineOSCore.loadPropeties()

-----------------------------------------------------------------------------------------------------------------------------------

return MineOSCore





