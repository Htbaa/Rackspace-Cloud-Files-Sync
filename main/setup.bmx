Rem
	bbdoc:
End rem
Type TApp Final
	Global applicationDir:String
	Global configFile:String
	
	Global rcf:TRackspaceCloudFiles
	Global rcfUsername:String
	Global rcfKey:String
	Global rcfLocation:String = TRackspaceCloudFiles.LOCATION_USA

	Rem
		bbdoc:
	End rem
	Function Setup()
		TApp.applicationDir = "Rackspace Cloud Files Sync"
		
		?Linux
		TApp.applicationDir = "." + TApp.applicationDir
		?
		
		TApp.applicationDir = GetUserAppDir() + "/" + TApp.applicationDir
		
		If FileType(TApp.applicationDir) = 0
			If Not CreateDir(TApp.applicationDir, True)
				RuntimeError "Failed to create application configuration directory"
			End If
		End If
		
		TApp.configFile = TApp.applicationDir + "/config"
		
		'Create a default configuration file
		If FileType(TApp.configFile) <> FILETYPE_FILE
			TApp.SaveConfigFile("", "", TRackspaceCloudFiles.LOCATION_USA)
		End If
		
		TApp.LoadConfigFile()
			
		'Load our certificates
		If FileType("ssl/cacert.pem") = FILETYPE_DIR Then TRackspaceCloudFiles.CAInfo = "ssl/cacert.pem"
		
		TApp.rcf = New TRackspaceCloudFiles
		TBackup.SetRCF(TApp.rcf)
	End Function

	Rem
		bbdoc:
	End rem
	Function SaveConfigFile(username:String, key:String, location:String)
		SaveText(username.Trim() + "~n" + key.Trim() + "~n" + location.Trim(), TApp.configFile)
		TApp.LoadConfigFile()
	End Function
	
	Rem
		bbdoc:
	End rem
	Function LoadConfigFile()
		Local credentials:String[] = LoadText(TApp.configFile).Split("~n")
		If Not credentials.Length >= 2 Then RuntimeError("Invalid configuration file!")
		TApp.rcfUsername = credentials[0].Trim()
		TApp.rcfKey = credentials[1].Trim()
		If credentials.Length >= 3 Then TApp.rcfLocation = credentials[2].Trim()
	End Function

	Rem
		bbdoc:
	End rem
	Function SetupRCF()
		Try
			TApp.rcf.Create(TApp.rcfUsername, TApp.rcfKey, TApp.rcfLocation)
		Catch ex:TRackspaceCloudFilesException
			Notify(ex.ToString(), True)
		End Try
	End Function
End Type
