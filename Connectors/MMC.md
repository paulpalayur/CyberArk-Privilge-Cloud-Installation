# Configuring MMC connector

## Prerequisites

* Install AutoIt3 from [here](https://www.autoitscript.com/site/autoit/downloads/)
* Install the Windows Remote Server Administration Tools on the Connector Server(s)
    * Server Manager → Manage → Add Roles and Features (follow the wizard)
    * For ADUC/DHCP/DNS: Go to Features → Remote Server Administration Tools
    * For GMPC: Go to Features → Group Policy Management
* Disable the UAC on the Connector Server(s)
    * Edit the Domain PSM Hardening GPO
    * Change the following setting to "Disabled"
        * Computer Configuration → Policies → Windows Settings → Security Settings → Local Policies → Security Options → User Account Controls → User Account Control: Run all administrators in Admin Approval Mode
    * GPMC (only) - Add the User/Group to the below policy who will launch GPMC
        * Computer Configuration → Policies → Windows Settings → Security Settings → Local Policies → User Rights Assignment → Allow Logon Locally
    * Run via an Admin PowerShell or CMD → gpupdate /force
    * Restart the PSM server

## Phase 1 - Create AutoIt script and test

* Make a copy of `PSMAutoItDispatcherSkeleton.au3`, which is located in the PSM installation folder/Components
* Rename this file and place it in a new location along with the following files which you can find from the Components folder

```
C:\Scripts\MMC\
PSMGenericClientDriver.dll
PSMGenericClientDriver.xml
PSMGenericClientWrapper.au3
PSMAutoItDispatcherSkeleton.au3 -> rename this file. For ex: PSMMMCDispatcher.au3
```

* Edit this file PSMMMCDispatcher.au3
* Set values for `$DISPATCHER_NAME` and `$CLIENT_EXECUTABLE`
* For example

```
Global Const $DISPATCHER_NAME  = "MMC Snap-ins" ; CHANGE_ME
Global Const $CLIENT_EXECUTABLE  = 'mmc "C:\Windows\System32\dsa.msc"' ; CHANGE_ME
```

* You can also create a custom MMC snap-in which includes limited tools like ADUC and DNS and set the $CLIENT\_EXECUTABLE path to the new .msc path
* It is recommended to test the AutoIt script that you developed before you compile it
* To test the script perform the following steps:
* You will have to add the following properties to the `PSMGenericClientDriver.xml` before testing

```
Note: update the property values with the correct details
<SessionProperties>
		<SessionProperty Name="SessionUUID" Value="0b4d3135-d824-4044-8a3f-555a72b72577" />
		<SessionProperty Name="Username" Value="TargetUsername" />
		<SessionProperty Name="Address" Value="Domain" />
		<SessionProperty Name="Password" Value="TargetPassword" />
		<SessionProperty Name="LogonDomain" Value="NetBIOSName" />
</SessionProperties>
```

* Launch cmd in the location that your new script and dependecy files are kept and run the below command

```
Note: make sure you have navigated to the dispactcher file location in cmd

"installation_path_of_AutoIt.exe" "Dispatcher_filename" "Path_to_the_Dispatche_FileName\" /test

For ex:
"C:\Program Files (x86)\AutoIt3\AutoIt3.exe" "PSMMMCDispatcher.au3" "C:\Scripts\MMC\" /test
```

* This should launch the msc console. You can also check the file for execution log`PSMGenericClientDriver.txt`
* Once your AutoIt script is working as expected, compile it to convert it to `.exe`
* There are multiple ways of compiling your script. One way which we tested was by using this application `C:\Program Files (x86)\AutoIt3\Aut2Exe\Aut2exe.exe`
* Once you compile your script and an .exe is generated test it by running the following command

```
Note: make sure you have navigated to the dispactcher exe file location in cmd

"Path_to_the_Dispatche_File\Dispatcher_filename" "Path_to_the_Dispatche_FileName\" /test

For ex:
"C:\Scripts\MMC\PSMMMCDispatcher.exe" "C:\Scripts\MMC\" /test
```

## Phase 2 - Updating PSM Components folder and PSM App Locker

* Copy the exe file to PSM installation folder/Components
* Update the `PSMConfigureAppLocker.xml` to include the following applications

```
Note: You can place this in the  <!-- PSM Components --> section
    <Application Name="MMC" Type="Exe" Path="C:\Windows\System32\mmc.exe" Method="Hash" />
    <Application Name="MMCustom" Type="Exe" Path="C:\Program Files (x86)\Cyberark\PSM\Components\PSMMMCDispatcher.exe" Method="Hash" />

Note: You may add the following section if you are planning to use .au3 instead of using .exe dispatcher. This is not recommended.
    <Application Name="AutoIt3" Type="Exe" Path="C:\Program Files (x86)\AutoIt3\AutoIt3.exe" Method="Publisher" />
```

* Save and close the file `PSMConfigureAppLocker.xml`
* Launch powershell as administrator and navigate to the PSM installation folder/Hardending
* Execute `.\PSMConfigureAppLocker.ps1`
* You should see the following result in the powershell console

```
CyberArk AppLocker's configuration script ended successfully.
True
```

* Restart Cyber-Ark Privileged Session Manager service

## Phase 3 - Updates to PVWA Web Portal

* Login to PVWA as Vault Administrator
* Navigate to https://pvwa-address/PasswordVault/v10/Classic/system.aspx
* Click on Options
* Navigate to Connection Components and create a copy of `PSM-VNCClientSample`
* To make a copy, right click on `PSM-VNCClientSample` and select copy, then right click on `Connection Components` and click `Paste Connection Component`
* Click on the new Connection Component that you created and Update the Id to PSM-COMPONENTNAME. For ex: PSM-MMC
* Set the `FullScreen` to `Yes`
* Navigate to `User Parameters -> AllowMappingLocalDrives` and set the `Value` to `No`
* Navigate to `Target Settings` and Update the following

```
ClientDispatcher: "{PSMComponentsFolder}\PSMMMCDispatcher.exe" "{PSMComponentsFolder}"

PSMMMCDispatcher.exe is the example name that we used in this document, rename to the the correct name
```

* Navigate to `Target Settings -> Lock Application Window` and update `MainWindowClass` to `MMCMainFrame`
* Apply and Save the changes
* Navigate to Platform Management under Administration Menu
* Select the platform that you want to associate this connector to and click on `Manage PSM connectos`
* Search for the connector that you created, for ex: PSM-MMC
* Click on that connector to associate it to this platform
* Restart Cyber-Ark Privileged Session Manager service
* Go to accounts menu and select the account that you want to launch MMC and select the connector name from the connect option to launch MMC.
