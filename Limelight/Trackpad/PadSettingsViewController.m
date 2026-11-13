//
//  PadSettingsViewController.m
//  iMoonlight
//

#import "PadSettingsViewController.h"
#import "PadSettings.h"
#import "PadHaptics.h"
#import "PadOutput.h"

enum { SectionTrackpad, SectionLayout, SectionKeyboard, SectionRemote, SectionHaptics, SectionCount };

/// A row: a slider or a switch bound to a setting.
@interface PadSettingRow : NSObject
@property (nonatomic, copy) NSString* title;
@property (nonatomic, copy, nullable) NSString* detail;
@property (nonatomic, copy) NSString* key;
@property (nonatomic) BOOL isSwitch;
@property (nonatomic) float min, max;
@end

@implementation PadSettingRow
+ (instancetype)slider:(NSString*)title key:(NSString*)key min:(float)min max:(float)max {
    PadSettingRow* r = [[PadSettingRow alloc] init];
    r.title = title;
    r.key = key;
    r.min = min;
    r.max = max;
    return r;
}
+ (instancetype)toggle:(NSString*)title detail:(NSString*)detail key:(NSString*)key {
    PadSettingRow* r = [[PadSettingRow alloc] init];
    r.title = title;
    r.detail = detail;
    r.key = key;
    r.isSwitch = YES;
    return r;
}
@end

@interface PadSettingsViewController () <UITextViewDelegate>
@end

@implementation PadSettingsViewController {
    NSArray<NSArray<PadSettingRow*>*>* _rows;
    UILabel* _shortcutStatus;
}

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        self.title = @"Ajustes do controle";
        _rows = @[
            @[[PadSettingRow slider:@"Velocidade do ponteiro" key:PadKeySensitivity min:0.5 max:5],
              [PadSettingRow slider:@"Aceleração do ponteiro" key:PadKeyAcceleration min:0 max:2],
              [PadSettingRow slider:@"Velocidade da rolagem" key:PadKeyScrollSpeed min:0.5 max:5],
              [PadSettingRow slider:@"Velocidade do zoom no PC (pinça)" key:PadKeyZoomSpeed min:0.2 max:3],
              [PadSettingRow toggle:@"Rolagem clássica" detail:@"Dedos para baixo rolam para baixo, como a roda do mouse" key:PadKeyInvertScroll]],
            @[[PadSettingRow toggle:@"Inverter telas" detail:@"Touchpad em cima, imagem do PC embaixo (retrato)" key:PadKeySwapScreens],
              [PadSettingRow toggle:@"Dicas de gestos" detail:@"Mostra a cola dos gestos no pé do touchpad" key:PadKeyShowHints],
              [PadSettingRow toggle:@"Escurecer parado" detail:@"Depois de 30 s sem toque o touchpad escurece; o próximo toque só acorda" key:PadKeyDimWhenIdle]],
            @[[PadSettingRow toggle:@"Autocorreção" detail:@"Corrige a palavra ao terminá-la e põe os acentos que faltam (nao → não). Toque na sugestão para manter o que digitou" key:PadKeyAutocorrect],
              [PadSettingRow toggle:@"Maiúscula automática" detail:@"Maiúscula no começo de cada frase" key:PadKeyAutoCapitalize],
              [PadSettingRow toggle:@"Atalho do \".\"" detail:@"Dois toques no espaço digitam ponto e espaço" key:PadKeyDoubleSpacePeriod],
              [PadSettingRow toggle:@"Português do Brasil" detail:@"Linha de acentos (´ ~ ^ `), ç e autocorreção em português. Desligado: teclado e autocorreção em inglês" key:PadKeyPortuguese],
              [PadSettingRow toggle:@"PC com teclas mortas (EUA internacional)" detail:@"Acentos saem como ' + a, igual ao teclado do PC. Desligue se o layout do PC não tiver teclas mortas" key:PadKeyDeadKeys],
              [PadSettingRow toggle:@"Digitar ao soltar o dedo" detail:@"Dá para deslizar até a tecla certa antes de digitar" key:PadKeyTypeOnRelease]],
            @[[PadSettingRow toggle:@"Marcador do cursor" detail:@"Um anel dourado mostra na imagem onde o cursor está e some sozinho" key:PadKeyCursorMarker],
              [PadSettingRow toggle:@"Reconectar sozinho" detail:@"Se a conexão cair ou você sair do app, volta para a mesma tela ao reabrir" key:PadKeyAutoReconnect]],
            @[],
        ];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                           target:self action:@selector(done)];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 72;
}

- (void)done {
    [self.view endEditing:YES];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView {
    return SectionCount;
}

- (NSString*)tableView:(UITableView*)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case SectionTrackpad: return @"Touchpad";
        case SectionLayout: return @"Tela";
        case SectionKeyboard: return @"Teclado";
        case SectionRemote: return @"Lpz Remote";
        default: return @"Vibração";
    }
}

- (NSString*)tableView:(UITableView*)tableView titleForFooterInSection:(NSInteger)section {
    if (section == SectionRemote) {
        return @"Atalhos: um por linha, no formato Rótulo = Ctrl+Alt+T. Teclas: Ctrl, Alt, Shift, Super, Enter, Esc, Tab, Espaço, Del, Home, End, PgUp, PgDn, PrtSc, setas, letras, números e F1 a F12. Aparecem em Teclas, depois de Colar.";
    }
    if (section == SectionHaptics) {
        return @"Cada ação tem a sua vibração e intensidade. Toda mudança toca uma amostra.";
    }
    return nil;
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == SectionRemote) return _rows[section].count + 2;
    return section == SectionHaptics ? PadHapticActionCount : _rows[section].count;
}

static UILabel* label(NSString* text, UIFont* font, UIColor* color) {
    UILabel* l = [[UILabel alloc] init];
    l.text = text;
    l.font = font;
    l.textColor = color;
    l.numberOfLines = 0;
    return l;
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {
    // Rows are few, so each is built fresh: no reuse bookkeeping for the bound controls.
    UITableViewCell* cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    UIStackView* stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 6;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:10],
        [stack.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-10],
    ]];

    if (indexPath.section == SectionHaptics) {
        [self buildHapticRow:(PadHapticAction)indexPath.row inStack:stack];
        return cell;
    }

    if (indexPath.section == SectionRemote && indexPath.row >= (NSInteger)_rows[SectionRemote].count) {
        if (indexPath.row == (NSInteger)_rows[SectionRemote].count) {
            [self buildNetworkRowInStack:stack];
        } else {
            [self buildShortcutsRowInStack:stack];
        }
        return cell;
    }

    PadSettingRow* row = _rows[indexPath.section][indexPath.row];
    if (row.isSwitch) {
        UIStackView* line = [[UIStackView alloc] init];
        line.axis = UILayoutConstraintAxisHorizontal;
        line.alignment = UIStackViewAlignmentCenter;
        line.spacing = 12;
        UIStackView* texts = [[UIStackView alloc] init];
        texts.axis = UILayoutConstraintAxisVertical;
        texts.spacing = 2;
        [texts addArrangedSubview:label(row.title, [UIFont systemFontOfSize:17], [UIColor labelColor])];
        if (row.detail != nil) {
            [texts addArrangedSubview:label(row.detail, [UIFont systemFontOfSize:13], [UIColor secondaryLabelColor])];
        }
        [line addArrangedSubview:texts];
        UISwitch* toggle = [[UISwitch alloc] init];
        toggle.on = [PadSettings boolForKey:row.key];
        [toggle setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        NSString* key = row.key;
        [toggle addAction:[UIAction actionWithHandler:^(UIAction* action) {
            [PadSettings setBool:((UISwitch*)action.sender).on forKey:key];
        }] forControlEvents:UIControlEventValueChanged];
        [line addArrangedSubview:toggle];
        [stack addArrangedSubview:line];
    } else {
        UILabel* title = label(@"", [UIFont systemFontOfSize:17], [UIColor labelColor]);
        NSString* name = row.title;
        void (^updateTitle)(float) = ^(float v) {
            title.text = [NSString stringWithFormat:@"%@: %.1f", name, v];
        };
        float value = [PadSettings floatForKey:row.key];
        updateTitle(value);
        [stack addArrangedSubview:title];
        UISlider* slider = [[UISlider alloc] init];
        slider.minimumValue = row.min;
        slider.maximumValue = row.max;
        slider.value = value;
        NSString* key = row.key;
        [slider addAction:[UIAction actionWithHandler:^(UIAction* action) {
            float v = roundf(((UISlider*)action.sender).value * 10) / 10;
            updateTitle(v);
            [PadSettings setFloat:v forKey:key];
        }] forControlEvents:UIControlEventValueChanged];
        [stack addArrangedSubview:slider];
    }
    return cell;
}

- (void)buildNetworkRowInStack:(UIStackView*)stack {
    [stack addArrangedSubview:label(@"Qualidade da imagem", [UIFont systemFontOfSize:17], [UIColor labelColor])];
    [stack addArrangedSubview:label(@"Automática: Wi-Fi na qualidade dos ajustes, dados móveis em 720p e 6 Mbps. Vale na próxima conexão.",
                                    [UIFont systemFontOfSize:13], [UIColor secondaryLabelColor])];
    UISegmentedControl* seg = [[UISegmentedControl alloc] initWithItems:@[@"Automática", @"Alta", @"Econômica"]];
    seg.selectedSegmentIndex = [PadSettings networkProfile];
    [seg addAction:[UIAction actionWithHandler:^(UIAction* action) {
        [PadSettings setNetworkProfile:(PadNetworkProfile)((UISegmentedControl*)action.sender).selectedSegmentIndex];
    }] forControlEvents:UIControlEventValueChanged];
    [stack addArrangedSubview:seg];
}

- (void)buildShortcutsRowInStack:(UIStackView*)stack {
    [stack addArrangedSubview:label(@"Atalhos personalizados", [UIFont systemFontOfSize:17], [UIColor labelColor])];
    UITextView* text = [[UITextView alloc] init];
    text.text = [PadSettings shortcuts];
    text.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightRegular];
    text.backgroundColor = [UIColor tertiarySystemFillColor];
    text.layer.cornerRadius = 10;
    text.textContainerInset = UIEdgeInsetsMake(10, 6, 10, 6);
    text.autocorrectionType = UITextAutocorrectionTypeNo;
    text.autocapitalizationType = UITextAutocapitalizationTypeSentences;
    text.keyboardAppearance = UIKeyboardAppearanceDark;
    text.delegate = self;
    [text.heightAnchor constraintEqualToConstant:132].active = YES;
    [stack addArrangedSubview:text];
    _shortcutStatus = label(@"", [UIFont systemFontOfSize:13], [UIColor secondaryLabelColor]);
    [stack addArrangedSubview:_shortcutStatus];
    [self checkShortcuts:text.text];
}

/// Conta os atalhos válidos e aponta a primeira linha que não deu para entender.
- (void)checkShortcuts:(NSString*)text {
    NSInteger ok = 0;
    NSString* bad = nil;
    for (NSString* raw in [text componentsSeparatedByString:@"\n"]) {
        NSString* line = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (line.length == 0) continue;
        NSRange eq = [line rangeOfString:@"="];
        NSString* combo = eq.location == NSNotFound ? line : [line substringFromIndex:NSMaxRange(eq)];
        if ([PadOutput codesForCombo:combo] != nil) ok++;
        else if (bad == nil) bad = line;
    }
    _shortcutStatus.textColor = bad != nil ? [UIColor systemOrangeColor] : [UIColor secondaryLabelColor];
    _shortcutStatus.text = bad != nil ? [NSString stringWithFormat:@"Não entendi: \"%@\"", bad]
                                      : [NSString stringWithFormat:@"%ld atalho%@ pronto%@", (long)ok, ok == 1 ? @"" : @"s", ok == 1 ? @"" : @"s"];
}

- (void)textViewDidChange:(UITextView*)textView {
    [self checkShortcuts:textView.text];
}

- (void)textViewDidEndEditing:(UITextView*)textView {
    [PadSettings setShortcuts:textView.text];
}

- (void)buildHapticRow:(PadHapticAction)action inStack:(UIStackView*)stack {
    UIStackView* line = [[UIStackView alloc] init];
    line.axis = UILayoutConstraintAxisHorizontal;
    line.alignment = UIStackViewAlignmentCenter;
    [line addArrangedSubview:label([PadHaptics nameForAction:action], [UIFont systemFontOfSize:17], [UIColor labelColor])];

    UIButton* feelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    feelButton.showsMenuAsPrimaryAction = YES;
    [feelButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [line addArrangedSubview:feelButton];
    [stack addArrangedSubview:line];

    UISlider* strength = [[UISlider alloc] init];
    strength.minimumValue = 0;
    strength.maximumValue = 100;
    strength.value = [PadHaptics strengthForAction:action];
    [strength addAction:[UIAction actionWithHandler:^(UIAction* a) {
        [PadHaptics setStrength:lroundf(((UISlider*)a.sender).value) forAction:action];
    }] forControlEvents:UIControlEventValueChanged];
    // Preview once the finger lets go, rather than on every step.
    [strength addAction:[UIAction actionWithHandler:^(UIAction* a) {
        [PadHaptics play:action];
    }] forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [stack addArrangedSubview:strength];

    [self refreshFeelButton:feelButton strength:strength action:action];
}

/// Shows the action's current feel on its button, with a menu to pick another.
- (void)refreshFeelButton:(UIButton*)button strength:(UISlider*)strength action:(PadHapticAction)action {
    PadHapticFeel current = [PadHaptics feelForAction:action];
    [button setTitle:[[PadHaptics nameForFeel:current] stringByAppendingString:@" ▾"] forState:UIControlStateNormal];
    strength.enabled = current != PadFeelOff;
    __weak PadSettingsViewController* weakSelf = self;
    __weak UIButton* weakButton = button;
    __weak UISlider* weakStrength = strength;
    NSMutableArray<UIAction*>* items = [NSMutableArray array];
    for (NSInteger f = 0; f < PadFeelCount; f++) {
        UIAction* item = [UIAction actionWithTitle:[PadHaptics nameForFeel:(PadHapticFeel)f] image:nil identifier:nil
                                           handler:^(UIAction* a) {
            [PadHaptics setFeel:(PadHapticFeel)f forAction:action];
            [PadHaptics play:action];
            if (weakButton != nil && weakStrength != nil) {
                [weakSelf refreshFeelButton:weakButton strength:weakStrength action:action];
            }
        }];
        item.state = f == current ? UIMenuElementStateOn : UIMenuElementStateOff;
        [items addObject:item];
    }
    button.menu = [UIMenu menuWithTitle:@"" children:items];
}

@end
