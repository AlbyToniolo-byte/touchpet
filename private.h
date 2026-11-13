// Funzioni private di macOS per tenere un elemento nella Touch Bar anche quando l'app non è in primo piano.
// Non sono documentate da Apple: vanno dichiarate a mano (stesso trucco di Pock e MTMR). Niente App Store.
#import <AppKit/AppKit.h>

// mostra/nasconde l'elemento nella Control Strip (la zona a destra con luminosità e volume)
extern void DFRElementSetControlStripPresenceForIdentifier(NSTouchBarItemIdentifier, BOOL);
// la X a sinistra che richiude la barra espansa
extern void DFRSystemModalShowsCloseBoxWhenFrontMost(BOOL);

@interface NSTouchBarItem ()
+ (void)addSystemTrayItem:(NSTouchBarItem *)item;
@end

@interface NSTouchBar ()
+ (void)presentSystemModalTouchBar:(NSTouchBar *)touchBar systemTrayItemIdentifier:(NSTouchBarItemIdentifier)identifier;
+ (void)minimizeSystemModalTouchBar:(NSTouchBar *)touchBar;
@end
