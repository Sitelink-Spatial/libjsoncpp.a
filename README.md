# libjsoncpp.a

xcframework wrapper for libjsoncpp


## Dependencies

    * xcode
    * brew install git


## Build

    ./build.sh build release arm64-apple-ios14.0


## Reference in Swift Module

``` swift

    .binaryTarget(
        name: "libjsoncpp.a",
        url: "https://github.com/Imajion/libjsoncpp.a/releases/download/r6/libjsoncpp.a.xcframework.zip",
        checksum: "5adf21677f3bfdc30419bf18d5367fa50e83a3d15578c74f83610fe976d62858"
    )

```
