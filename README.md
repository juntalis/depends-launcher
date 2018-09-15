Simple launcher for [Dependency Walker](http://www.dependencywalker.com/) that determines the platform (x86|x64|ia64) of a windows image (dll, exe, etc) and launches the appropriate version of depends.exe to view its dependencies. Its main purpose is for use in a context menu entry to easily view an image's dependencies.

## For Pre-Packaged Releases

Running the **setup.cmd** file included in the zip file should download all required versions of Dependency Walker. If not, let me know.

Sorry, no registry files for you.

## Building

**Note**: Coming back to this way later, the build script approach was a bad call. I recently updated it to hopefully support all VC versions between 2005-2015, but drop an issue if you can't build it or need something for 2015+.

The **build.cmd** file should automate the process of building. It downloads the appropriate versions of Dependency Walker and sets up the necessary subfolders. Additionally, it will generate registry files to add the program to the context menu for .exe files.

**Example Usage:**

	build.cmd

Will download the appropriate files, and build the main executable.

	build.cmd test

Will download the appropriate files, build the main executable, in addition to some small tests, then run the main executable against the tests.

	build.cmd help

Will print usage info that includes any other args that can be specified.

## Additional Credits
* [atifaziz](https://gist.github.com/atifaziz) - The build script currently utilizes a [wget-esque script](https://gist.github.com/967373) written in JScript for the Windows Script Host.
* [Dave Gilpin](http://gilpin.us/) - The build script currently utilizes the [IconSiphon](http://gilpin.us/IconSiphon/) script to extract the icon of depends.exe
* [Steve P. Miller](http://stevemiller.net/) - Dependency Walker can be found at [its website](http://www.dependencywalker.com/).
