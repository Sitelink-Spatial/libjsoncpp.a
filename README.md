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
        url: "https://github.com/Imajion/libjsoncpp.a/releases/download/r5/libjsoncpp.a.xcframework.zip",
        checksum: "24c0c602e327f0c363b773ab9a14bee382ffa54dcc603294aee2f5a09d9d71c3"
    )

```