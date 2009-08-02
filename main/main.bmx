'Make sure a file called credentials.txt is available
'On the first line the username is expected. On the second line the API key is expected.
Local credentials:String[] = LoadText("credentials.txt").Split("~n")
If Not credentials.Length = 2
	RuntimeError("Invalid configuration file!")
End If

'Load our certificates
TRackspaceCloudFiles.CAInfo = "ssl/cacert.pem"

'Create our TRackspaceCloudFiles object
Local rcf:TRackspaceCloudFiles = New TRackspaceCloudFiles.Create(credentials[0].Trim(), credentials[1].Trim())
Try
'	rcf.Container("test").Remove()
Catch e:TRackspaceCloudFilesContainerException
End Try

TBackup.SetRCF(rcf)

TBackup.CreateBackup("F:\Fotos\Christiaan", ["Thumbs.db"], "christiaan")

Type TBackup
	Global rcf:TRackspaceCloudFiles
	
	Function SetRCF(rcf:TRackspaceCloudFiles)
		TBackup.rcf = rcf
	End Function
	
	Function _check()
		If Not TBackup.rcf
			Throw "TBackup.rcf:TRackspaceCloudFiles hasn't been set yet!"
		End If
	End Function
	
	Function CreateBackup:Byte(directory:String, ignore:String[], containerName:String)
		TBackup._check()
		Local index:TDirectoryIndex = New TDirectoryIndex.Create(directory)
		Local container:TRackspaceCloudFilesContainer = TBackup.rcf.CreateContainer(containerName)
		
		For Local file:TFile = EachIn index.fileList
			If ignore <> Null
				For Local rule:String = EachIn ignore
					If rule[0] = "*" And file.filename.Contains(rule[1..])
						Continue
					Else If file.filename = rule
						Continue
					End If
				Next
			End If
		
			'Strip root directory name + trailing slash
			Local stripped:String = file.FullName()[directory.Length + 1..]
			Local cloudFile:TRackspaceCloudFileObject = container.FileObject(stripped)
			cloudFile.PutFile(file.FullName())
		Next
		Return True
	End Function
	
	Function RestoreBackup:Byte(container:String, directory:String)
		TBackup._check()
		Return False
	End Function
End Type