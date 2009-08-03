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
TBackup.SetRCF(rcf)

Type TBackup
	Global rcf:TRackspaceCloudFiles
	Global msgReceiver:Object
	
	Function SetRCF(rcf:TRackspaceCloudFiles)
		TBackup.rcf = rcf
	End Function
	
	Function SetMsgReceiver(msgReceiver:Object)
		TBackup.msgReceiver = msgReceiver
	End Function
	
	Function _check()
		If Not TBackup.rcf
			Throw "TBackup.rcf:TRackspaceCloudFiles hasn't been set yet!"
		End If
	End Function
	
	Function CreateBackup:Byte(directory:String, ignore:String[], containerName:String)
		TBackup._check()
		Local index:TDirectoryIndex = New TDirectoryIndex.Create(directory)

		If TBackup.msgReceiver Then TBackup.msgReceiver.SendMessage("DirectoryIndex", index)
		
		Local container:TRackspaceCloudFilesContainer = TBackup.rcf.CreateContainer(containerName)

		Local objectList:TList = container.Objects()
		
		'Remove files that have been removed from the local system
		For Local fileObject:TRackspaceCloudFileObject = EachIn objectList
			Local remove:Byte = True
			For Local file:TFile = EachIn index.fileList
				Local stripped:String = file.FullName()[directory.Length + 1..]
				If stripped = fileObject.Name()
					remove = False
					Exit
				End If
			Next
			
			If remove
				If TBackup.msgReceiver Then TBackup.msgReceiver.SendMessage("Removing", fileObject)
				fileObject.Remove()
			End If
		Next
		
		'Now start processing each local file
		For Local file:TFile = EachIn index.fileList
			Local skip:Byte = False
			'Match filename against ignore list
			If ignore <> Null
				For Local rule:String = EachIn ignore
					If rule[0] = "*" And file.filename.Contains(rule[1..])
						skip = True
						Exit
					Else If file.filename = rule
						skip = True
						Exit
					End If
				Next
			End If

			'Strip root directory name + trailing slash
			Local stripped:String = file.FullName()[directory.Length + 1..]
			
			'Skip existing files
			For Local fileObject:TRackspaceCloudFileObject = EachIn objectList
				'Check if names match
				If fileObject.Name() = stripped
					'If so fetch HEAD data
					fileObject.Head()
					
					'If the ETag doesn't match than the file is different. So remove it
					If fileObject.ETag() <> file.ETag()
						If TBackup.msgReceiver Then TBackup.msgReceiver.SendMessage("Removing", fileObject)
						fileObject.Remove()
						Exit
					End If
					
					'ETag's matched so there's no reason to not skip this one
					skip = True
					If TBackup.msgReceiver Then TBackup.msgReceiver.SendMessage("Skipping", fileObject)
					Exit
				End If
			Next
			
			If skip Then Continue

			If TBackup.msgReceiver Then TBackup.msgReceiver.SendMessage("Processing", file)
			Local cloudFile:TRackspaceCloudFileObject = container.FileObject(stripped)
			Try
				cloudFile.PutFile(file.FullName())
				If TBackup.msgReceiver Then TBackup.msgReceiver.SendMessage("Processed", cloudFile)
			Catch ex:TRackspaceCloudBaseException
				If TBackup.msgReceiver Then TBackup.msgReceiver.SendMessage("Error", ex)
			End Try
		Next
		
		If TBackup.msgReceiver Then TBackup.msgReceiver.SendMessage("Finished", Null)
		Return True
	End Function
	
	Function RestoreBackup:Byte(container:String, directory:String)
		TBackup._check()
		Return False
	End Function
End Type