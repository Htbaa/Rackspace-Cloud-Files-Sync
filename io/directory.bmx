Rem
	bbdoc:
End Rem
Type TDirectoryIndex
	Field rootDirectory:String
	Field fileList:TList

	Rem
		bbdoc:
	End Rem
	Method Create:TDirectoryIndex(rootDirectory:String)
		Self.rootDirectory = RealPath(rootDirectory)
		Self.fileList = New TList
		Self.IndexDirectory(rootDirectory)
		Return Self
	End Method

	Rem
		bbdoc:
	End Rem
	Method TotalSize:Int()
		Local size:Long
		For Local file:TFile = EachIn Self.fileList
			size:+file.size
		Next
		Return size
	End Method

	Rem
		bbdoc:
	End Rem
	Method ToString:String()
		Local str:String
		For Local file:TFile = EachIn Self.fileList
			Local filename:String = file.FullName().Replace(Self.rootDirectory, "")
			If filename.StartsWith("/")
				str:+filename[1..] + "~n"
			Else
				str:+filename + "~n"
			End If
		Next
		Return str
	End Method

	Rem
		bbdoc: Private method
	End Rem
	Method IndexDirectory(directory:String)
		Local files:String[] = LoadDir(directory)

		If files <> Null
			For Local file:String = EachIn files
				Select FileType(directory + "/" + file)
					Case 1
						'Add file to list
						Self.fileList.AddLast(New TFile.Create(directory + "/" + file))
					Case 2
						'Iterate directory
						Self.IndexDirectory(directory + "/" + file)
				End Select
			Next
		End If
	End Method
End Type