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

Rem
	bbdoc:
End Rem
Type TBackup
	Global rcf:TRackspaceCloudFiles
	Global msgReceiver:Object

	'Settings for backup
	Global backupDirectory:String
	Global backupContainer:String
	Global backupIgnore:String[]
	
	'Settings for restoring
	Global restoreDirectory:String
	Global restoreContainer:String
	
	Rem
		bbdoc:
	End Rem	
	Function SetRCF(rcf:TRackspaceCloudFiles)
		TBackup.rcf = rcf
	End Function

	Rem
		bbdoc:
	End Rem	
	Function SetMsgReceiver(msgReceiver:Object)
		TBackup.msgReceiver = msgReceiver
	End Function
	

	Rem
		bbdoc:
	End Rem	
	Function SetBackupDirectory(backupDirectory:String)
		TBackup.backupDirectory = backupDirectory
	End Function

	Rem
		bbdoc:
	End Rem	
	Function SetBackupContainer(backupContainer:String)
		TBackup.backupContainer = backupContainer
	End Function

	Rem
		bbdoc:
	End Rem
	Function SetRestoreDirectory(restoreDirectory:String)
		TBackup.restoreDirectory = restoreDirectory
		'Check if our backup directory is valid
		If FileType(TBackup.restoreDirectory) <> FILETYPE_DIR Then Throw "TBackup.restoreDirectory isn't a directory!"
	End Function

	Rem
		bbdoc:
	End Rem
	Function SetRestoreContainer(restoreContainer:String)
		TBackup.restoreContainer = restoreContainer
	End Function
		
	Rem
		bbdoc:
	End Rem	
	Function _check(_type:String)
		If Not TBackup.rcf Then Throw "TBackup.rcf:TRackspaceCloudFiles hasn't been set yet!"
		
		Select _type
			Case "backup"
				If TBackup.backupDirectory.Length = 0 Then Throw "TBackup.backupDirectory hasn't been set yet!"
				If TBackup.backupContainer.Length = 0 Then Throw "TBackup.backupContainer hasn't been set yet!"
			Case "restore"
				If TBackup.restoreDirectory.Length = 0 Then Throw "TBackup.restoreDirectory hasn't been set yet!"
				If TBackup.restoreContainer.Length = 0 Then Throw "TBackup.restoreContainer hasn't been set yet!"
		End Select
	End Function
	
	Rem
		bbdoc:
	End Rem	
	Function CreateBackup:Byte()
		TBackup._check("backup")
		Local index:TDirectoryIndex = New TDirectoryIndex.Create(TBackup.backupDirectory)

		If TBackup.msgReceiver Then TBackup.msgReceiver.SendMessage("DirectoryIndex", index)
		
		Local container:TRackspaceCloudFilesContainer = TBackup.rcf.CreateContainer(TBackup.backupContainer)

		Local objectList:TList = container.Objects()
		
		'Remove files that have been removed from the local system
		For Local fileObject:TRackspaceCloudFileObject = EachIn objectList
			Local remove:Byte = True
			For Local file:TFile = EachIn index.fileList
				Local stripped:String = file.FullName()[TBackup.backupDirectory.Length + 1..]
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
			If TBackup.backupIgnore <> Null
				For Local rule:String = EachIn TBackup.backupIgnore
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
			Local stripped:String = file.FullName()[TBackup.backupDirectory.Length + 1..]
			
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
					If TBackup.msgReceiver Then TBackup.msgReceiver.SendMessage("Skipping", file)
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
	
	Rem
		bbdoc:
	End Rem	
	Function RestoreBackup:Byte()
		TBackup._check("restore")
		
		Local index:TDirectoryIndex = New TDirectoryIndex.Create(TBackup.restoreDirectory)

		If TBackup.msgReceiver Then TBackup.msgReceiver.SendMessage("DirectoryIndex", index)
		
		Local container:TRackspaceCloudFilesContainer = TBackup.rcf.CreateContainer(TBackup.restoreContainer)

		Local objectList:TList = container.Objects()
		For Local fileObject:TRackspaceCloudFileObject = EachIn objectList
			'Extract directory from filename
			Local parts:String[] = ExtractDir(fileObject.Name()).Split("/")
			Local dir:String = TBackup.restoreDirectory
			'And create every directory that doesn't exist yet
			For Local part:String = EachIn parts
				If part.Length = 0 Then Continue
				dir:+"/" + part
				If FileType(dir) = 0 Then CreateDir(dir)
			Next

			Local localFile:String = dir + "/" + StripDir(fileObject.Name())
			Local file:TFile = New TFile.Create(localFile)
			
			'Check if file exists
			If FileType(localFile) = FILETYPE_FILE

				fileObject.Head()
				'ETag mismatch - Delete local file
				If fileObject.ETag() <> file.ETag()
					If TBackup.msgReceiver Then TBackup.msgReceiver.SendMessage("Removing", localFile)
					DeleteFile(localFile)
				'ETag matches, the file will be left untouched
				Else
					If TBackup.msgReceiver Then TBackup.msgReceiver.SendMessage("Skipping", file)
					Continue
				End If
			End If
			
			'Download the file
			Try
				If TBackup.msgReceiver Then TBackup.msgReceiver.SendMessage("Processing", file)
				fileObject.GetFile(localFile)
				If TBackup.msgReceiver Then TBackup.msgReceiver.SendMessage("Processed", fileObject)
			Catch ex:TRackspaceCloudBaseException
				If TBackup.msgReceiver Then TBackup.msgReceiver.SendMessage("Error", ex)
			End Try
		Next

		If TBackup.msgReceiver Then TBackup.msgReceiver.SendMessage("Finished", Null)
		Return True
	End Function
End Type