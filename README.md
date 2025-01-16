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
        url: "https://github.com/Imajion/libjsoncpp.a/releases/download/r8/libjsoncpp.a.xcframework.zip",
        checksum: "3ef3892221d7fdb703099f61266281214e725b3201aa09df20e8aab3f3b20c95"
    )

```
