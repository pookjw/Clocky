# Contribution Guidelines

This document defines the coding conventions, header authoring rules, and architectural guidelines for **Clocky**.

For PepperUICore information and examples of UIKit-based watchOS apps, see [MiscellaneousPepperUICore](https://github.com/pookjw/MiscellaneousWWDC25/tree/main/MiscellaneousPepperUICore).

For watchOS UI, prefer an available, suitable PepperUICore component over its generic UIKit counterpart—for example, use `PUICListCollectionViewController` instead of `UICollectionViewController` for a native watch-style list.

## 1. Language, Deployment Target & Memory Management

- **No SwiftUI**: The project is written strictly in Objective-C (`.m`) and Objective-C++ (`.mm`). The watch app uses UIKit (`_UIKitPrivate`), ClockKit (`_ClockKitPrivate`), `PepperUICore`, `_WatchKitPrivate`, and `NanoTimeKit`; the iOS companion uses public UIKit.
- **Minimum Deployment Targets**: `watchOS 9.0` and `iOS 15.0`, the respective minimum versions supported by Xcode 27.3.
- **Manual Retain-Release (MRR / Non-ARC)**:
  - ARC is disabled (`CLANG_ENABLE_OBJC_ARC = NO`).
  - Manage object lifetimes explicitly using `retain`, `release`, `autorelease`, and `[super dealloc]` in `-dealloc`.
  - Instantiate objects with `[[Class alloc] init]` (or the appropriate designated initializer) instead of `[Class new]`; declarations that make `+new` unavailable are unaffected.
  - When a class requires a custom initializer to establish its invariants, mark plain `-init`, `+new`, and any other inherited initializers that bypass those invariants as `NS_UNAVAILABLE`.
  - Prefer property setters over direct instance-variable assignment, including in initializers when it is safe. Use direct ivar access when required to avoid unsafe dynamic dispatch or side effects during initialization, and in `dealloc` for releasing owned objects.
- **Mutable Collection Capacity**:
  - When the expected collection size is known or reasonably bounded, initialize mutable collections with an appropriate capacity, such as `initWithCapacity:`, rather than the default initializer.
- **Copyable Properties**:
  - Prefer `copy` for writable properties whose values support `NSCopying`, including strings and collections, when the property represents a value or snapshot. A collection copy is shallow and does not copy its elements.
  - Use `retain` or another appropriate ownership policy when object identity, shared mutation, or mutable property semantics are required; `NSCopying` conformance alone does not make copying appropriate. Preserve the actual ownership semantics of framework declarations, delegate properties, and other externally defined APIs.
- **Property Initialization and Nullability**:
  - Mark object properties `nullable` (or their pointer types `_Nullable`) if they can be `nil` after initialization, including properties populated later in lifecycle callbacks such as `viewDidLoad`. Use nonnull only when initialization or a guaranteed accessor ensures a value whenever the property is observed.
  - Check nullable values at use sites or assert a documented lifecycle invariant before passing them to APIs that require nonnull values. Preserve the contracts of externally defined properties and computed class properties.

## 2. Constants & Extern Declarations (`Defines.h`)

- Define shared constants and keys (such as `NSUserDefaults` keys) in `Defines.h` / `Defines.m` using the `CLKY_EXTERN` macro and function accessors rather than file-local `static` variables:
  ```objc
  #ifdef __cplusplus
  #define CLKY_EXTERN  extern "C" __attribute__((visibility ("default")))
  #else
  #define CLKY_EXTERN  extern __attribute__((visibility ("default")))
  #endif

  CLKY_EXTERN NSString * selectedFaceArchiveKey(void);
  ```

## 3. Calling Private APIs

- **No Objective-C Runtime Dynamic Dispatch for API Calls**:
  - Avoid calling private APIs via `objc_msgSend`, `NSClassFromString`, `objc_lookUpClass`, `objc_getClass`, `NSSelectorFromString`, or `sel_registerName`.
  - Instead, declare the classes, methods, and properties in the appropriate `.xcframework` header (`.h`) and export their symbols/classes in the corresponding `.tbd` stub file so they are checked at compile time and linked directly.
- **Availability Annotations over `-respondsToSelector:`**:
  - When calling private APIs, do **not** guard calls with `-respondsToSelector:`. Instead, annotate declarations with `API_AVAILABLE(...)` (and `@available` if version checks are needed above the `watchOS 9.0` deployment target).
  - (`-respondsToSelector:` should only be used for checking optional delegate protocol methods defined by our own delegates.)
- **Minimal Declarations**:
  - Only declare the classes, protocols, properties, methods, and enums in private `.h` files that are actually used by the project. Do not dump unused methods or remove needed ones.
  - Omit unnecessary comments in recreated SDK/private headers.
  - Place each declaration in the header and framework that actually owns it, not merely the framework that uses it. Verify ownership against SDK exports or runtime binaries, and import the owning framework's header where needed. For example, `CLKDevice` belongs to ClockKit and is declared in `_ClockKitPrivate`, not NanoTimeKit.
  - Keep distinct classes and protocols in their own appropriately named headers rather than combining unrelated definitions in one file. Use forward declarations and imports for dependencies, and match the original framework's header layout when known.
  - When a used symbol from a public framework such as UIKit or WatchKit fails to link through its corresponding `_Private` XCFramework, add the symbol to that XCFramework's `.tbd` in the section for the actual exporting framework. Verify the export against the SDK or runtime binary first; do not assume every declared symbol is exported. Synchronize the slices using `InterfaceGenerator`.

## 4. Private Header (`.h`) Authoring Rules

- **Strict Typing & Nullability**:
  - Wrap headers in `NS_HEADER_AUDIT_BEGIN(nullability, sendability)` / `NS_HEADER_AUDIT_END(nullability, sendability)` (or `NS_ASSUME_NONNULL_BEGIN` / `NS_ASSUME_NONNULL_END`).
  - Never use untyped `id` out of convenience. Always specify the exact class or protocol type.
  - Annotate nullable parameters, return types, and properties explicitly with `_Nullable` / `nullable`.
  - Reproduce the original API's nullability, including nullable block pointers, block parameters, collection elements, and `null_resettable` properties where applicable. Check SDK headers or runtime behavior; do not infer nonnull solely from a convenient call site. If a private contract cannot be verified, document the uncertainty rather than presenting a guess as fact.
  - For local variables only, an explicit `_Nullable` annotation may be omitted when the value is immediately checked with an assertion before use, such as `Method method = class_getInstanceMethod(...); assert(method != NULL);`. This does not change the nullability of properties or API contracts. Assertions can be disabled in release builds, so use a runtime check instead when a missing value must be handled safely in production.
  - Use `__kindof` where polymorphic subclasses are returned or passed (e.g., `__kindof NTKFaceBundle *`, `__kindof NTKFace *`, `__kindof UICollectionViewCell *`).
- **Protocol Requirements**:
  - Reproduce the original protocol's required and optional members; mark each section explicitly with `@required` or `@optional` instead of relying on Objective-C's default. Verify the classification against SDK headers or runtime metadata where available, and document uncertainties for private protocols.
  - Do not apply the project's optional-delegate convention to system protocols without checking their actual contract.
- **`NS_NOESCAPE` on Synchronous Blocks**:
  - Annotate non-escaping block parameters (such as enumeration blocks or synchronous configuration blocks) with `NS_NOESCAPE`, e.g.:
    ```objc
    - (void)enumerateFaceBundlesOnDevice:(CLKDevice *)device includingLegacy:(BOOL)includingLegacy withBlock:(void (NS_NOESCAPE ^)(__kindof NTKFaceBundle *faceBundle))block;
    ```
- **Preserve Xcode / iOS UIKit Header Structure in `_UIKitPrivate`**:
  - When adding UIKit declarations to `_UIKitPrivate`, mirror the exact file names, category names, declaration positions, and import order from the iOS `UIKit.framework` headers (without comments).
  - For example:
    - `UIViewGeometry`, `UIViewHierarchy`, `UIViewGestureRecognizers` categories in `UIView.h`
    - `UIContainerViewControllerProtectedMethods`, `UIContainerViewControllerCallbacks` categories in `UIViewController.h`
    - `UICollectionViewCellRegistration` in `UICollectionViewItemRegistration.h`
    - `NSIndexPath (UIKitAdditions)` in `NSIndexPath+UIKitAdditions.h`

## 5. Delegate Pattern Conventions

- Communicate between child/presented view controllers and their parent/presenting view controllers using a delegate protocol.
- Mark delegate callbacks as `@optional` and follow the naming pattern:
  ```objc
  @protocol NameViewControllerDelegate <NSObject>
  @optional
  - (void)nameViewController:(NameViewController *)viewController didSelectItem:(ItemType *)item;
  @end
  ```

## 6. Method Swizzling Conventions

- All method swizzling lives in `Swizzler.h` / `Swizzler.mm` and is invoked from `+[AppDelegate load]` in `AppDelegate.mm`.
- Use `#include <objc/runtime.h>` and `#include <objc/message.h>` (use `#include` instead of `#import` for `<objc/...>` headers).
- Use `reinterpret_cast` for all function pointer and `IMP` casts.
- Organize each swizzled method under nested C++ namespaces `swizzler::<ClassName>::<methodName>` containing `original`, `custom`, and `swizzle()`:
  ```objc
  namespace swizzler {
      namespace NTKFaceDescriptor {
          namespace isAvailableForDevice {
              BOOL (* _Nullable original)(::NTKFaceDescriptor *self, SEL _cmd, CLKDevice *device);
              BOOL custom(::NTKFaceDescriptor *self, SEL _cmd, CLKDevice *device) {
                  return YES;
              }
              void swizzle() {
                  Method method = class_getInstanceMethod([::NTKFaceDescriptor class], @selector(isAvailableForDevice:));
                  assert(method != NULL);
                  original = reinterpret_cast<decltype(original)>(method_getImplementation(method));
                  method_setImplementation(method, reinterpret_cast<IMP>(custom));
              }
          }
      }
  }
  ```

## 7. Synchronizing XCFrameworks with `InterfaceGenerator`

- Whenever headers (`.h`) or `.tbd` exports are modified in a custom `.xcframework` (`_UIKitPrivate`, `_WatchKitPrivate`, `_ClockKitPrivate`, `PepperUICore`, `NanoTimeKit`), make the primary edits in the `watchos-arm64_x86_64-simulator` slice and run `InterfaceGenerator -p <project_root>` to propagate headers and `.tbd` targets across all slices.
- Ensure `InterfaceGenerator/Subclasses` only defines generators for the `.xcframework` bundles actively used by the project.

## 8. Direct Objective-C Dispatch

- In app code, prefer `__attribute__((objc_direct))` for internal helper methods and the `direct` property attribute for internal properties when their accessors do not require dynamic dispatch or overriding.
- Do not use direct dispatch for lifecycle overrides, protocol or delegate callbacks, target-action selectors, notifications, KVC/KVO, swizzled methods, or other methods invoked through the Objective-C runtime.
- `InterfaceGenerator` is excluded from this convention; preserve its existing dispatch behavior.
