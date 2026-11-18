# NanoTimeKit & ClockFace Research

## Overview

`NanoTimeKit.framework` (`/System/Library/PrivateFrameworks/NanoTimeKit.framework/NanoTimeKit`) is the private watchOS framework that powers Apple Watch clock faces, face bundles, face view controllers, and face customization. The system `ClockFace.app` (`/Applications/ClockFace.app/ClockFace`, bundle identifier `com.apple.clockface`) hosts the active watch face experience on watchOS.

## Core Classes

### `CLKDevice` (`ClockKit.framework`)
- Exported by `/System/Library/Frameworks/ClockKit.framework/ClockKit` (though omitted from public watchOS `ClockKit` headers).
- Declared in `_ClockKitPrivate.xcframework`, whose linker stub points to the system ClockKit framework; NanoTimeKit headers import that declaration where needed.
- `+ (CLKDevice *)currentDevice` returns the active device configuration descriptor used throughout `NanoTimeKit` for querying device capabilities, screen metrics, and face compatibility.

### `NTKFaceBundleManager`
- Singleton accessed via `+ (NTKFaceBundleManager *)sharedManager`.
- Manages discovery and lookup of `NTKFaceBundle` plugins located in `/System/Library/NanoTimeKit/FaceBundles/`.
- Holds an `NTKFaceBundleLoader *loader` property (`-loader`) responsible for loading face bundle classes from disk.
- Enumeration methods:
  - `- (void)enumerateFaceBundlesOnDevice:(CLKDevice *)device withBlock:(void (NS_NOESCAPE ^)(__kindof NTKFaceBundle *faceBundle))block;`
    Forwards to `-enumerateFaceBundlesOnDevice:includingLegacy:withBlock:` with `includingLegacy:NO`.
  - `- (void)enumerateFaceBundlesOnDevice:(CLKDevice *)device includingLegacy:(BOOL)includingLegacy withBlock:(void (NS_NOESCAPE ^)(__kindof NTKFaceBundle *faceBundle))block;`

### `NTKFaceBundleLoader`
- Enumerates and instantiates `NTKFaceBundle` subclasses via:
  - `- (void)enumerateFaceBundleClassesIgnoringCache:(BOOL)ignoringCache withBlock:(void (NS_NOESCAPE ^)(__kindof NTKFaceBundle *faceBundle))block;`
  - Note: Despite the method name containing `Classes`, the loader instantiates each bundle class (`alloc`/`init`) and passes the `NTKFaceBundle *` instance to `block`.

### `NTKFaceBundle`
- Base class for all clock face bundles (e.g., `NTKZeusAnalogFaceBundle`, `NTKPoodleFaceBundle`, `NTKHermes2026FaceBundle`, `NTKKaleidoscopeFaceBundle`, `NTKSnowglobeFaceBundle`).
- Key properties and methods:
  - `@property (class, nonatomic, readonly, nullable) NSString *identifier;`
  - `@property (nonatomic, readonly) Class faceClass;` — returns the `NTKFace` subclass associated with the bundle.
  - `@property (nonatomic, readonly, nullable) NSNumber *legacyFaceStyle;` — non-nil for legacy face styles.
  - `- (nullable __kindof NTKFace *)defaultFaceForDevice:(CLKDevice *)device;` — constructs the default `NTKFace` instance for the given `CLKDevice`.
  - `- (nullable NSString *)galleryTitleForDevice:(CLKDevice *)device;` — localized user-facing title of the face for the given device (some bundles return `nil` from `-galleryTitle` and only populate `-galleryTitleForDevice:`).

### `NTKFace` & `NTKFaceDescriptor`
- `NTKFace` represents a configured watch face model.
- `+ (BOOL)isRestrictedForDevice:(CLKDevice *)device;` determines whether a face class is restricted on the given hardware/SKU/region.
- `NTKFaceDescriptor` represents a face style/bundle descriptor and checks availability via `- (BOOL)isAvailableForDevice:(CLKDevice *)device;`.

### `NTKFaceViewController`
- Subclass of `UIViewController` that renders and manages an `NTKFace` and its `NTKFaceView`.
- Initialized via:
  - `- (instancetype)initWithFace:(NTKFace *)face configuration:(void (NS_NOESCAPE ^ _Nullable)(NTKFaceViewController *faceViewController))configuration;`

## Editing and Persistence

- The watchOS 10.5 simulator's `NTKFaceViewController` runtime metadata includes `showEditingUIAnimated:fromZoomLevel:`, `canStopEditing`, and `hideFaceEditingUIAnimated:destination:completion:`. Clocky's category-list edit button presents a separate controller for the currently selected face and uses these methods to start and finish editing. The `0` zoom level and destination are experimental; private method behavior, completion semantics, and the editor UI require device verification across watchOS versions.
- The same runtime declares `NTKFace` as conforming to `NSSecureCoding` and `NSCopying`, with `encodeWithCoder:` and `initWithCoder:`. Clocky saves the selected face to `NSUserDefaults` as a secure keyed archive, including after editing, and attempts secure decoding on launch. It falls back to a default face on decoding failure without overwriting an existing archive until the user selects or edits a face. Archive round trips, subclass compatibility, and external photo/complication resources have not yet been verified on device.
- The previous selected identifier is not migrated. This storage is app-local and is not a change to the system watch-face library.

## Face Filtering & Device Restrictions (Why Some Faces Are Hidden by Default)

On a standard watchOS device or simulator, `-[NTKFaceBundleManager enumerateFaceBundlesOnDevice:withBlock:]` only returns ~32 of the 84 installed face bundles. Three mechanisms filter or fallback faces:

1. **Legacy Face Style Filtering (`includingLegacy:NO`)**:
   - In `-[NTKFaceBundleManager enumerateFaceBundlesOnDevice:includingLegacy:withBlock:]`, when `includingLegacy` is `NO`, any `NTKFaceBundle` whose `-legacyFaceStyle` returns a non-nil `NSNumber` (32 bundles, including `NTKZeusAnalogFaceBundle`, `NTKZeusSpectrumFaceBundle`, `NTKKaleidoscopeFaceBundle`, `NTKExtraLargeFaceBundle`, `NTKUtilityFaceBundle`, etc.) is skipped.
   - Calling `-enumerateFaceBundlesOnDevice:includingLegacy:YES withBlock:` includes these legacy bundles.

2. **Face Class Device Restriction (`+[NTKFace isRestrictedForDevice:]`)**:
   - During enumeration, `NTKFaceBundleManager` queries `[faceBundle.faceClass isRestrictedForDevice:device]`.
   - While `+[NTKFace isRestrictedForDevice:]` returns `NO` on the base class, 20 face subclasses override `+isRestrictedForDevice:` in their own `.bundle` binaries to check hardware SKU, edition (e.g., Hermès / Zeus, Nike / Victory, Ultra), or region:
     - Hermès faces: `NTKZeusAnalogFace`, `NTKSpectrumZeusFace`, `NTKPoodleFace`, `NTKHadesFace`, `NTKBellonaFace`, `NTKSquallFace`, `NTKHermes2026FaceBundle.Hermes2026Face`, `NTKSecretariatFace`
     - Other restricted faces: `NTKPride2025FaceBundle.Pride2025Face`, `NTKAegirFace`, `NTKEsterbrookFace`, `NTKAtiumFace`, `NTKPlumeriaFace`, `NTKPride2026FaceBundleFaceBundle.Pride2026Face`, `NTKPrideDigitalFace`, `NTKPrideAnalogFace`, `NTKPrideAnalogRichFace`, `NTKParmesanFace`, `NTKUnity2025Face`, `NTKParameciumFace`
   - Swizzling `+isRestrictedForDevice:` on every loaded `faceBundle.faceClass` (enumerated via `NTKFaceBundleManager.sharedManager.loader`) to return `NO` unlocks all 84 face bundles.

3. **Legacy Face Style Availability Fallback (`-[NTKFaceDescriptor isAvailableForDevice:]`)**:
   - For legacy-styled faces such as `NTKZeusAnalogFaceBundle` (style `14`) and `NTKZeusSpectrumFaceBundle` (style `42`), `-defaultFaceForDevice:` calls `+[NTKFace defaultFaceOfStyle:forDevice:initCustomization:]`.
   - Internally, `_convertToValidFaceStyleForDevice(style, device)` allocates an `NTKFaceDescriptor` with `-initWithFaceStyle:` and checks `-[NTKFaceDescriptor isAvailableForDevice:device]` (which calls `_NTKFaceStyleIsAvailable`, checking `device.collectionType == 5` or `device.isZeusBlack`).
   - If `-isAvailableForDevice:` returns `NO`, `_convertToValidFaceStyleForDevice` falls back to style `4` (`NTKExtraLargeFace`) instead of instantiating `NTKZeusAnalogFace` or `NTKSpectrumZeusFace`.
   - Swizzling `-[NTKFaceDescriptor isAvailableForDevice:]` to return `YES` prevents this fallback and allows `defaultFaceForDevice:` to instantiate the true `NTKZeusAnalogFace` and `NTKSpectrumZeusFace`.
