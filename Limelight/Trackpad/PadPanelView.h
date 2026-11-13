//
//  PadPanelView.h
//  iMoonlight
//
//  The half of the screen that isn't the stream in portrait: a slim bar of buttons
//  (Keyboard, PC keys, Video off, Settings, Disconnect) over the trackpad. The keyboard takes
//  the iPhone keyboard's height along the bottom, with the trackpad still usable above it;
//  PC keys cover the whole panel. Side by side (sideways with video off), the keyboard fills
//  most of the screen on the left, top to bottom, and the trackpad the rest on the right,
//  without its hints. The bar stays hidden until a swipe down from the top of the trackpad.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PadPanelView;

@protocol PadPanelViewDelegate <NSObject>
- (void)padPanelWantsSettings:(PadPanelView*)panel;
- (void)padPanelWantsDisconnect:(PadPanelView*)panel;
- (void)padPanelWantsVideoToggled:(PadPanelView*)panel;
/// Ditado em português: o que for falado é digitado no PC.
- (void)padPanelWantsDictation:(PadPanelView*)panel;
@end

@interface PadPanelView : UIView

@property (nonatomic, weak, nullable) id<PadPanelViewDelegate> delegate;
/// Shows the Video button as "Video on" while the video is off.
@property (nonatomic) BOOL videoOff;
/// Keyboard on the left at full height, bar and trackpad on the right.
@property (nonatomic) BOOL sideBySide;
/// Side by side, how far the keyboard stays in from the left edge (to clear the camera).
@property (nonatomic) CGFloat keyboardInset;

- (void)openKeyboard;
/// Closes the keyboard or PC keys and lets go of anything held.
- (void)resetInput;

@end

@class PadLandscapeView;

@protocol PadLandscapeViewDelegate <NSObject>
- (void)landscapeWantsSettings:(PadLandscapeView*)view;
- (void)landscapeWantsDisconnect:(PadLandscapeView*)view;
- (void)landscapeWantsVideoToggled:(PadLandscapeView*)view;
- (void)landscapeWantsDictation:(PadLandscapeView*)view;
/// Reconectar já, para aplicar outra qualidade de imagem.
- (void)landscapeWantsReconnect:(PadLandscapeView*)view;
/// Zoom local da imagem (1 = tela inteira, sem zoom).
- (void)landscape:(PadLandscapeView*)view wantsZoom:(CGFloat)zoom;
@end

/// Celular deitado: a imagem do PC ocupa a tela e uma faixa vertical de funções fica à
/// esquerda. Cada função abre um painel feito para a tela deitada: teclado e teclas do PC
/// embaixo, touchpad translúcido à direita (a imagem continua visível), zoom e monitores em
/// cartões pequenos. Toques fora da faixa e do painel aberto vão direto para a imagem.
@interface PadLandscapeView : UIView

@property (nonatomic, weak, nullable) id<PadLandscapeViewDelegate> delegate;
/// Largura da faixa, já contando a margem segura da esquerda.
@property (nonatomic, readonly) CGFloat stripWidth;
@property (nonatomic) CGFloat zoom;

/// Fecha o painel aberto e solta qualquer tecla presa.
- (void)resetInput;

@end

/// Ditado em português (Lpz Remote): mostra o que está sendo ouvido, deixa corrigir e envia.
@interface PadDictationViewController : UIViewController
/// Chamado com o texto final; withEnter = também apertar Enter depois.
@property (nonatomic, copy, nullable) void (^onSend)(NSString* text, BOOL withEnter);
@end

NS_ASSUME_NONNULL_END
