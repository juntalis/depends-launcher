'Visual Basic script for extracting icons.
'Just drop files on the script.
'The default extract location is the script path.

if wscript.arguments.count=0 then msgbox "Drop files on me to extract the icons."

'set up global variables
Set FSO = CreateObject("Scripting.FileSystemObject")
Set wshell = CreateObject("wscript.shell")
dim groups()
secva=0
dim ressec
dim iconsectionoffset

'change the following line only to extract icons to other than the script path
ExtractPath=left(wscript.scriptfullname, len(wscript.scriptfullname) - len(wscript.scriptname)) & "..\"


for each DroppedFile in wscript.arguments
	if not ExtractIcons(DroppedFile) then faillist=faillist & chr(10) & DroppedFile
next

if not faillist="" then msgbox "Unable to find icons for the following files:" & faillist

Function ExtractIcons(filepath)
	icongroupnum = 0
	icongroupnumprovided=false
	filepath=wshell.ExpandEnvironmentStrings(filepath)
	if not fso.fileexists(filepath) then 'make sure file still exists
		If Not fso.folderexists(filepath) Then
			Exit Function
		End If
	end if
	select case lcase(right(filepath,3)) 'determine type of file
		case "lnk", "url" 'windows shortcut
			set fl = wshell.createshortcut(filepath)
			on error resume next
			icongroupnumprovided=true
			icongroupnum = cint(mid(fl.iconlocation,instrrev(fl.iconlocation,",")+1))
			if err and lcase(right(filepath,3)) = "url" then
				on error goto 0
				filepath=wshell.ExpandEnvironmentStrings(getprog("a.html"))
				if not instr(filepath,",")=0 then
					icongroupnum = cint(mid(filepath,instrrev(filepath,",")+1))
					if not instrrev(filepath,",")=1 then
						filepath=wshell.ExpandEnvironmentStrings(left(filepath,instrrev(filepath,",")-1))
					end if
				end if
			else
				on error goto 0
				if instrrev(fl.iconlocation,",")=1 then
					filepath=wshell.ExpandEnvironmentStrings(fl.targetpath)
					if fso.folderexists(filepath) then
						filepath=wshell.ExpandEnvironmentStrings(getprog(fl.targetpath))
						if not instr(filepath,",")=0 then
							icongroupnum = cint(mid(filepath,instrrev(filepath,",")+1))
							if not instrrev(filepath,",")=1 then
								filepath=wshell.ExpandEnvironmentStrings(left(filepath,instrrev(filepath,",")-1))
							end if
						end if
					end if
				else
					filepath=wshell.ExpandEnvironmentStrings(left(fl.iconlocation,instrrev(fl.iconlocation,",")-1))
				end if
			end if
			if lcase(right(filepath,3)) = "ico" then
				fso.copyfile filepath, ExtractPath & fso.getfile(filepath).name
				ExtractIcons=true
				exit function
			end if
			set fl = fso.OpenTextFile(filepath,1)
		case "exe","dll","sys", "scr", "bpl", "dpl", "cpl", "ocx", "acm", "ax" 'windows executable files
			Set fl = FSO.OpenTextFile(filepath, 1)
		case "ico" 'ico files
			ExtractIcons=true
			exit function
		case else 'document files
			icongroupnumprovided=true
			filepath = replace(getProg(filepath),"""","")
			if filepath="" then exit function
			if not instr(filepath,",") = 0 then
				icongroupnum = cint(mid(filepath,instrrev(filepath,",")+1))
				filepath=wshell.ExpandEnvironmentStrings(left(filepath,instrrev(filepath,",")-1))
			end if
			filepath=wshell.ExpandEnvironmentStrings(filepath)
			if lcase(right(filepath,3)) = "ico" then
				fso.copyfile filepath, ExtractPath & fso.getfile(filepath).name
				ExtractIcons=true
				exit function
			end if
			if not fso.fileexists(filepath) then 'try to find path if not given
				if not wshell.ExpandEnvironmentStrings("%systemroot%") = "%systemroot%" then
					if not fso.fileexists(wshell.ExpandEnvironmentStrings("%systemroot%") & "\" & filepath) then
						if not fso.fileexists(wshell.ExpandEnvironmentStrings("%systemroot%") & "\system32\" & filepath) then
							exit function
						else
							filepath=wshell.ExpandEnvironmentStrings("%systemroot%") & "\system32\" & filepath
						end if
					else
						filepath=wshell.ExpandEnvironmentStrings("%systemroot%") & "\" & filepath
					end if
				else
					if not fso.fileexists("c:\windows\" & filepath) then
						if not fso.fileexists("c:\windows\system32\" & filepath) then
							exit function
						else
							filepath="c:\windows\system32\" & filepath
						end if
					else
						filepath="c:\windows\" & filepath
					end if
				end if
			end if
			Set fl = FSO.OpenTextFile(filepath, 1)
	end select
	filename=fso.getfile(filepath).name
	fl.skip 60
	PEoffset=getNum(fl.read(4))
	fl.skip PEoffset-64
	if not fl.read(2)="PE" then
		fl.close
		exit function
	end if
	fl.skip 18
	optheadsize = getNum(fl.read(2))
	fl.skip 94
	datadirsize = getNum(fl.read(4))
	fl.skip optheadsize - 96
	for a = 1 to datadirsize 'get resource offset
		secname=replace(fl.read(8),chr(0),"0")
		fl.skip 4
		secVA=getnum(fl.read(4))
		secsize=getNum(fl.read(4))
		secoffset=getNum(fl.read(4))
		fl.skip 16
		if instr(lcase(secname),".rsrc")>0 then
			rsrcSectionFound=true
			exit for
		end if
	next
	if not rsrcSectionFound then
		fl.close
		exit function
	end if
	fl.skip secoffset-(peoffset + 120 +(optheadsize-96)+(40*a))
	ressec=fl.read(secsize)
	fl.close
	for a=0 to getnum(mid(ressec,13,2)) + getnum(mid(ressec,15,2)) 'offset to icon groups section
		rsrctype=getnum(mid(ressec,17 + (a * 8),4))
		if rsrctype=14 then
			GroupSectionFound = true
			groupsectionoffset=getnum(mid(ressec,21 + (a * 8),3))
		elseif rsrctype=3 then
			IconSectionFound = true
			iconsectionoffset=getnum(mid(ressec,21 + (a * 8),3))
		end if
	next
	if not GroupSectionFound then
		exit function
	end if
	if not IconSectionFound then
		exit function
	end if
	redim groups(getnum(mid(ressec,groupsectionoffset+13,2)) + getnum(mid(ressec,groupsectionoffset+15,2)),3)
	for a = 0 to ubound(groups,1)-1 'get group ids and subdirs
		if getnum(mid(ressec,groupsectionoffset+20+ (a * 8),1))>127 then
			groupid=getnum(mid(ressec,groupsectionoffset+17+ (a * 8),3))
			groupstrlen=getnum(mid(ressec,groupid+1,2))
			groups(a,0)=replace(mid(ressec,groupid+3,groupstrlen*2),chr(0),"")
		else
			groups(a,0)=getnum(mid(ressec,groupsectionoffset+17+ (a * 8),4))
		end if
		if getnum(mid(ressec,groupsectionoffset+24+ (a * 8),1))>127 then
			groups(a,1)=getnum(mid(ressec,groupsectionoffset+21+ (a * 8),3))
			GroupDataEntryFound=false
		else
			groups(a,1)=getnum(mid(ressec,groupsectionoffset+21+ (a * 8),4))
			GroupDataEntryFound=true
		end if
		if groups(a,0)=abs(icongroupnum) and icongroupnum <0 and icongroupnumprovided then
			groupindx=a
			exit for
		end if
	next
	if icongroupnum >- 1 and icongroupnumprovided then
		groupindx = icongroupnum
		do until GroupDataEntryFound
			if getnum(mid(ressec,groups(groupindx,1)+24,1)) >127 then
				groups(groupindx,1)=getnum(mid(ressec,groups(groupindx,1)+21,3))
			else
				groups(groupindx,1)=getnum(mid(ressec,groups(groupindx,1)+21,4))
				GroupDataEntryFound=true
			end if
		loop
	else
		do until GroupDataEntryFound
			for a = 0 to ubound(groups,1)-1
				if getnum(mid(ressec,groups(a,1)+24,1)) >127 then
					groups(a,1)=getnum(mid(ressec,groups(a,1)+21,3))
				else
					groups(a,1)=getnum(mid(ressec,groups(a,1)+21,4))
					GroupDataEntryFound=true
				end if
			next
		loop
	end if
	for a = 0 to ubound(groups,1)-1
		groups(a,1)=getnum(mid(ressec,groups(a,1)+1,4))
	next
	
	if icongroupnumprovided then 'get specified group
		writeicon groupindx, filename
	else 'get all groups
		for a = 0 to ubound(groups,1)-1
			writeicon a, filename
		next
	end if
	ExtractIcons=true
end Function

function writeicon(groupindex,filename)
	imgcnt= getnum(mid(ressec,(groups(groupindex,1)-secva)+5,2))
	imageoffset=6 + (imgcnt * 16)
	redim imgids(imgcnt,4)
	for imagenm=0 to imgcnt-1
		imgids(imagenm,3)=mid(ressec,(groups(groupindex,1)-secva)+7+(imagenm * 14),12)
		imgids(imagenm,0) = getnum(mid(ressec,(groups(groupindex,1)-secva)+19+(imagenm * 14),2))
	next

	'get icon ids and subdirs
	for a=0 to getnum(mid(ressec,iconsectionoffset+13,2)) + getnum(mid(ressec,iconsectionoffset+15,2)) - 1
		if getnum(mid(ressec,iconsectionoffset+20+ (a * 8),1))>127 then
			iconid=getnum(mid(ressec,iconsectionoffset+17+ (a * 8),3))
			iconstrlen=getnum(mid(ressec,iconid+1,2))
			iconid=replace(mid(ressec,iconid+3,iconstrlen*2),chr(0),"")
		else
			iconid=getnum(mid(ressec,iconsectionoffset+17+ (a * 8),4))
		end if
		if getnum(mid(ressec,iconsectionoffset+24+ (a * 8),1))>127 then
			iconoffset=getnum(mid(ressec,iconsectionoffset+21+ (a * 8),3))
			IconDataEntryFound=false
		else
			iconoffset=getnum(mid(ressec,iconsectionoffset+21+ (a * 8),4))
			IconDataEntryFound=true
		end if
		for b=0 to ubound(imgids,1)-1
			if iconid = imgids(b,0) then
				imgids(b,1) = iconoffset
				exit for
			end if
		next
		if iconid >= imgids(ubound(imgids,1)-1,0) then exit for
	next
	do until IconDataEntryFound
		for a = 0 to ubound(imgids,1)-1
			if getnum(mid(ressec,imgids(a,1)+24,1)) >127 then
				imgids(a,1)=getnum(mid(ressec,imgids(a,1)+21,3))
			else
				imgids(a,1)=getnum(mid(ressec,imgids(a,1)+21,4))
				IconDataEntryFound=true
			end if
		next
	loop
	for a = 0 to ubound(imgids,1)-1
		imgids(a,2)=getnum(mid(ressec,imgids(a,1)+5,4))
		imgids(a,1)=getnum(mid(ressec,imgids(a,1)+1,4))
	next

	icoheader=""
	icoimgs=""
	imageoffset=6+(ubound(imgids,1)*16)
	for e=0 to ubound(imgids,1)-1
		icoheader = icoheader & imgids(e,3) & getByteString(imageoffset,4)
		imageoffset = imageoffset + imgids(e,2)
		icoimgs=icoimgs & mid(ressec,(imgids(e,1)-secva)+1,imgids(e,2))
	next
	if fso.fileexists(ExtractPath & left(filename,len(filename)-4) & "_" & groups(groupindex,0) & ".ico") then exit function
	set icofl = fso.createtextfile(ExtractPath & left(filename,len(filename)-4) & "_" & groups(groupindex,0) & ".ico",true)
	icofl.write getByteString(0,2) & getByteString(1,2) & getByteString(ubound(imgids,1),2) & icoheader & icoimgs
	icofl.close
end function

Function getNum(str) 'convert byte string to number
	if len(str)=0 then
		getNum=0
		exit function
	end if
	getNum = Asc(Mid(str,1,1))
	for a = 2 to len(str)
		getNum=getNum + (Asc(Mid(str,a,1)) * (256 ^ (a-1)))
	next
End Function

Function getByteString(num,NumberOfBytes) 'convert number to byte string
	tempnum=num
	for a = NumberOfBytes to 2 step -1
		if tempnum => (256 ^ (a-1))  then
			byt=int(tempnum/(256 ^ (a-1)))
			getByteString=chr(int(tempnum/(256 ^ (a-1)))) & getByteString
			tempnum = tempnum - (byt * (256 ^ (a-1)))
		else
			getByteString=chr(0) & getByteString
		end if
	next
	getByteString = chr(tempnum) & getByteString
End Function

function getProg(filepath) 'get program associated with a document
	on error resume next
	If fso.folderexists(filepath) Then
		progid=wshell.regread("HKEY_CLASSES_ROOT\Folder\")
	Else
		progid=wshell.regread("HKEY_CLASSES_ROOT\" & mid(filepath,instrrev(filepath,".")) & "\")
	End If
	If Not progid="" Then
		tempprog=wshell.regread("HKEY_CLASSES_ROOT\" & progid & "\DefaultIcon\")
		clsid=wshell.regread("HKEY_CLASSES_ROOT\" & progid & "\CLSID\")
		If Not clsid="" And len(tempprog)<6 Then
			getprog=wshell.regread("HKEY_CLASSES_ROOT\CLSID\" & clsid & "\DefaultIcon\")
		Else
			getProg=tempprog
		End If
	Else
		getProg=wshell.regread("HKEY_CLASSES_ROOT\" & mid(filepath,instrrev(filepath,".")) & "\DefaultIcon\")
	End If
end function