@set @junk=1 /* vim:set ft=javascript:
@echo off
cscript //nologo //e:jscript "%~dpnx0" %*
goto :eof
*/
//
// Global variables
//
var stdin = WScript.StdIn;
var stdout = WScript.StdOut;
var stderr = WScript.StdErr;

function writeln(s) {
	stdout.WriteLine(s);
}
function write(s) {
	stdout.Write(s);
}
function alert(s) {
	echo(s);
}
function echo(s) {
	WScript.Echo(s);
}

function unzip(file, dir) {
	var fso = new ActiveXObject('Scripting.FileSystemObject');
	if (!fso.FolderExists(dir)) {
		fso.CreateFolder(dir);
	}
	var shell = new ActiveXObject('Shell.Application');
	var dst = shell.NameSpace(fso.getFolder(dir).Path);
	var zip = shell.NameSpace(fso.getFile(file).Path);
	// http://msdn.microsoft.com/en-us/library/ms723207.aspx
	// 4: Do not display a progress dialog box.
	// 16: Click "Yes to All" in any dialog box displayed.
	dst.CopyHere(zip.Items(), 4 + 16);
}

try {
	var wshargs = WScript.Arguments;
	var args = [];
	for (var i = 0; i < wshargs.length; i++) args.push(wshargs(i));
	unzip(args[0], args[1]);
} catch (e) {
	stderr.WriteLine(e.message == null ? e.toString() : e.message);
	WScript.Quit(-1);
}
