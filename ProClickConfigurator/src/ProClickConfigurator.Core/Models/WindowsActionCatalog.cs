namespace ProClickConfigurator.Core.Models;

public static class WindowsActionCatalog
{
    private const ushort Backspace = 0x08;
    private const ushort Tab = 0x09;
    private const ushort Enter = 0x0D;
    private const ushort Shift = 0x10;
    private const ushort Control = 0x11;
    private const ushort Alt = 0x12;
    private const ushort Escape = 0x1B;
    private const ushort Space = 0x20;
    private const ushort PageUp = 0x21;
    private const ushort PageDown = 0x22;
    private const ushort End = 0x23;
    private const ushort Home = 0x24;
    private const ushort Left = 0x25;
    private const ushort Up = 0x26;
    private const ushort Right = 0x27;
    private const ushort Down = 0x28;
    private const ushort Delete = 0x2E;
    private const ushort Zero = 0x30;
    private const ushort A = 0x41;
    private const ushort C = 0x43;
    private const ushort D = 0x44;
    private const ushort E = 0x45;
    private const ushort I = 0x49;
    private const ushort L = 0x4C;
    private const ushort M = 0x4D;
    private const ushort R = 0x52;
    private const ushort S = 0x53;
    private const ushort T = 0x54;
    private const ushort V = 0x56;
    private const ushort W = 0x57;
    private const ushort X = 0x58;
    private const ushort Y = 0x59;
    private const ushort Z = 0x5A;
    private const ushort LeftWindows = 0x5B;
    private const ushort F4 = 0x73;
    private const ushort VolumeMute = 0xAD;
    private const ushort VolumeDown = 0xAE;
    private const ushort VolumeUp = 0xAF;
    private const ushort MediaNext = 0xB0;
    private const ushort MediaPrevious = 0xB1;
    private const ushort MediaStop = 0xB2;
    private const ushort MediaPlayPause = 0xB3;
    private const ushort Period = 0xBE;

    public const string PassthroughId = "system.passthrough";
    public const string DisabledId = "system.disabled";
    public const string HyperShiftId = "system.hypershift";

    public static IReadOnlyList<WindowsActionDefinition> All { get; } =
    [
        Action(PassthroughId, "Default / pass through", "Mouse", WindowsActionKind.Passthrough),
        Action(DisabledId, "Disable button", "Mouse", WindowsActionKind.Disabled),
        Action(HyperShiftId, "HyperShift modifier", "Mouse", WindowsActionKind.HyperShift),
        Mouse("mouse.left", "Left click", MouseButtonId.Left),
        Mouse("mouse.right", "Right click", MouseButtonId.Right),
        Mouse("mouse.middle", "Middle click", MouseButtonId.Middle),
        Mouse("mouse.back", "Back", MouseButtonId.Back),
        Mouse("mouse.forward", "Forward", MouseButtonId.Forward),
        Mouse("mouse.tilt-left", "Horizontal scroll left", MouseButtonId.TiltLeft),
        Mouse("mouse.tilt-right", "Horizontal scroll right", MouseButtonId.TiltRight),

        Shortcut("edit.copy", "Copy", "Editing", Control, C),
        Shortcut("edit.paste", "Paste", "Editing", Control, V),
        Shortcut("edit.cut", "Cut", "Editing", Control, X),
        Shortcut("edit.undo", "Undo", "Editing", Control, Z),
        Shortcut("edit.redo", "Redo", "Editing", Control, Y),
        Shortcut("edit.select-all", "Select all", "Editing", Control, A),
        Shortcut("edit.delete", "Delete", "Editing", Delete),
        Shortcut("edit.backspace", "Backspace", "Editing", Backspace),
        Shortcut("edit.enter", "Enter", "Editing", Enter),
        Shortcut("edit.escape", "Escape", "Editing", Escape),
        Shortcut("edit.tab", "Tab", "Editing", Tab),
        Shortcut("edit.space", "Space", "Editing", Space),

        Shortcut("navigation.home", "Home", "Navigation", Home),
        Shortcut("navigation.end", "End", "Navigation", End),
        Shortcut("navigation.page-up", "Page up", "Navigation", PageUp),
        Shortcut("navigation.page-down", "Page down", "Navigation", PageDown),
        Shortcut("navigation.up", "Arrow up", "Navigation", Up),
        Shortcut("navigation.down", "Arrow down", "Navigation", Down),
        Shortcut("navigation.left", "Arrow left", "Navigation", Left),
        Shortcut("navigation.right", "Arrow right", "Navigation", Right),
        Shortcut("navigation.browser-back", "Browser back", "Navigation", Alt, Left),
        Shortcut("navigation.browser-forward", "Browser forward", "Navigation", Alt, Right),
        Shortcut("navigation.reopen-tab", "Reopen closed tab", "Navigation", Control, Shift, T),

        Shortcut("windows.task-view", "Task view", "Windows", LeftWindows, Tab),
        Shortcut("windows.show-desktop", "Show desktop", "Windows", LeftWindows, D),
        Shortcut("windows.file-explorer", "Open File Explorer", "Windows", LeftWindows, E),
        Shortcut("windows.settings", "Open Settings", "Windows", LeftWindows, I),
        Shortcut("windows.search", "Windows search", "Windows", LeftWindows, S),
        Shortcut("windows.run", "Run dialog", "Windows", LeftWindows, R),
        Shortcut("windows.lock", "Lock PC", "Windows", LeftWindows, L),
        Shortcut("windows.screenshot", "Screen snip", "Windows", LeftWindows, Shift, S),
        Shortcut("windows.close", "Close window", "Windows", Alt, F4),
        Shortcut("windows.switch-window", "Switch window", "Windows", Alt, Tab),
        Shortcut("windows.virtual-left", "Previous virtual desktop", "Windows", Control, LeftWindows, Left),
        Shortcut("windows.virtual-right", "Next virtual desktop", "Windows", Control, LeftWindows, Right),
        Shortcut("windows.minimize-all", "Minimize all", "Windows", LeftWindows, M),
        Shortcut("windows.emoji", "Emoji picker", "Windows", LeftWindows, Period),
        Shortcut("windows.clipboard", "Clipboard history", "Windows", LeftWindows, V),
        Shortcut("windows.zoom-reset", "Reset zoom", "Windows", Control, Zero),

        Shortcut("media.play-pause", "Play / pause", "Media", MediaPlayPause),
        Shortcut("media.stop", "Stop", "Media", MediaStop),
        Shortcut("media.previous", "Previous track", "Media", MediaPrevious),
        Shortcut("media.next", "Next track", "Media", MediaNext),
        Shortcut("media.mute", "Mute", "Media", VolumeMute),
        Shortcut("media.volume-down", "Volume down", "Media", VolumeDown),
        Shortcut("media.volume-up", "Volume up", "Media", VolumeUp),
    ];

    private static readonly IReadOnlyDictionary<string, WindowsActionDefinition> ById =
        All.ToDictionary(action => action.Id, StringComparer.Ordinal);

    public static WindowsActionDefinition Get(string id)
    {
        return ById.TryGetValue(id, out var action)
            ? action
            : throw new KeyNotFoundException($"Unknown Windows action '{id}'.");
    }

    public static bool TryGet(string id, out WindowsActionDefinition? action)
    {
        return ById.TryGetValue(id, out action);
    }

    private static WindowsActionDefinition Action(
        string id,
        string name,
        string category,
        WindowsActionKind kind)
    {
        return new WindowsActionDefinition(id, name, category, kind);
    }

    private static WindowsActionDefinition Mouse(string id, string name, MouseButtonId button)
    {
        return new WindowsActionDefinition(
            id,
            name,
            "Mouse",
            WindowsActionKind.MouseButton,
            MouseButton: button);
    }

    private static WindowsActionDefinition Shortcut(
        string id,
        string name,
        string category,
        params ushort[] keys)
    {
        return new WindowsActionDefinition(
            id,
            name,
            category,
            WindowsActionKind.KeyboardShortcut,
            VirtualKeys: keys);
    }
}
