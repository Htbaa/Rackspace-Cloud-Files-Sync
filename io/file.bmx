Rem
	bbdoc:
End Rem
Type TFile
	Field path:String
	Field filename:String
	Field size:Long
	Field mtime:Int
	
	Rem
		bbdoc:
	End Rem
	Method Create:TFile(fullpath:String)
		Self.path = ExtractDir(fullpath)
		Self.filename = StripDir(fullpath)
		Self.size = FileSize(fullpath)
		Self.mtime = FileTime(fullpath)
		Return Self
	End Method
	
	Rem
		bbdoc:
	End Rem
	Method FullName:String()
		Return Self.path + "/" + Self.filename
	End Method
End Type
