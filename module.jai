#if OS == .WINDOWS {
    #load "windows.jai";
} else #if OS == .MACOS {
    #load "macos.jai";
} else #if OS == .LINUX {
    #load "linux.jai";
} else {
    #assert false;
}
