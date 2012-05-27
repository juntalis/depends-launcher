Simple launcher for [Dependency Walker](http://www.dependencywalker.com/) that determines the platform (x86|x64|ia64) of an exe and launches the appropriate version of depends.exe to view its dependencies. It's main purpose is for use in a context menu entry to easily view an exe's dependencies.

## Building
The **build.bat** file should automate the process of building. It downloads the appropriate versions of Dependency Walker and sets up the necessary subfolders. Additionally, it will generate registry files to add the program to the context menu for .exe files.

**Example Usage:**

	build.bat

Will download the appropriate files, and build the main executable.

	build.bat test

Will download the appropriate files, build the main executable, in addition to some small tests, then run the main executable against the tests.

	build.bat help

Will print usage info that includes any other args that can be specified.

## Additional Credits
* [atifaziz](https://gist.github.com/atifaziz) - The build script currently utilizes a [wget-esque script](https://gist.github.com/967373) written in JScript for the Windows Script Host.
* [Dave Gilpin](http://gilpin.us/) - The build script currently utilizes the [IconSiphon](http://gilpin.us/IconSiphon/) script to extract the icon of depends.exe
* [Steve P. Miller](http://stevemiller.net/) - Dependency Walker can be found at [its website](http://www.dependencywalker.com/).
