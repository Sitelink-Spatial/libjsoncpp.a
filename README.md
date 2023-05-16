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
        url: "https://github.com/Imajion/libjsoncpp.a/releases/download/r1/libjsoncpp.a.xcframework.zip",
        checksum: "e42ab4061f371dbf2d1b3589eb13e45a5eb2fdafa6dce519a2df8bc9e554d8a3"
    )

```