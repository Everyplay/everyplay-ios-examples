# Everyplay iOS examples

All examples link Everyplay framework from a relative path. To get started, please clone
the repository at https://github.com/Everyplay/everyplay-ios-sdk/ to the same subdirectory
where you'll place `everyplay-ios-examples`. No git submodule usage planned.

```
% git clone https://github.com/Everyplay/everyplay-ios-sdk.git
% git clone https://github.com/Everyplay/everyplay-ios-examples.git
% cd everyplay-ios-examples
```

## Graphics and media:

- EveryplayRecord
    - Basic audio/video recording integration against custom EAGLView implementation
    - Supports OpenGL ES1/ES2 and MSAA anti-aliased rendering
    - Audio engine used : FMOD Sound System by Firelight Technologies

- EveryplayTutorial
    - Same as EveryplayRecord but without Everyplay functionality built-in, used
      for online tutorial available at https://developers.everyplay.com/
    - Audio engine used : FMOD Sound System by Firelight Technologies

- EveryplayGLKit
    - Basic video recording test against GLKit and GLKViewController

## Everyplay API:

- EveryplayLogin
    - Show user data after login

- EveryplayVideo
    - Lists popular videos on a custom UITableViewController with playback support
