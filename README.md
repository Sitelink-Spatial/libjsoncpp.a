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
        url: "https://github.com/Imajion/libjsoncpp.a/releases/download/r7/libjsoncpp.a.xcframework.zip",
        checksum: "cc48c1edf9136ec454a1d8a15ed7104bedbf2838199c9c382678f0dc6a9fd78c"
    )

```
