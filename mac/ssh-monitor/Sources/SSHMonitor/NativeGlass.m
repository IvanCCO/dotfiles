#import "NativeGlass.h"

// Public macOS 26 API, declared locally so older SDKs can build the fallback.
@interface SSHMonitorGlassAPI : NSView
@property(nonatomic, strong) NSView *contentView;
@property(nonatomic) CGFloat cornerRadius;
@end

NSView *SSHMonitorGlassBackground(BOOL solidBackground) {
    if (solidBackground) {
        NSView *view = [[NSView alloc] initWithFrame:NSZeroRect];
        view.wantsLayer = YES;
        view.layer.backgroundColor = NSColor.windowBackgroundColor.CGColor;
        return view;
    }
    if (@available(macOS 26.0, *)) {
        Class glassClass = NSClassFromString(@"NSGlassEffectView");
        if (glassClass) {
            SSHMonitorGlassAPI *glass = [[glassClass alloc] initWithFrame:NSZeroRect];
            glass.cornerRadius = 16;
            glass.contentView = [[NSView alloc] initWithFrame:NSZeroRect];
            return glass;
        }
    }
    NSVisualEffectView *view = [[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
    view.material = NSVisualEffectMaterialPopover;
    view.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    view.state = NSVisualEffectStateActive;
    return view;
}
