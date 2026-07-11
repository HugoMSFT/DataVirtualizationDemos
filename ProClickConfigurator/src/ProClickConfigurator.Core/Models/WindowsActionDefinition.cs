namespace ProClickConfigurator.Core.Models;

public enum WindowsActionKind
{
    Passthrough,
    Disabled,
    HyperShift,
    MouseButton,
    KeyboardShortcut,
}

public sealed record WindowsActionDefinition(
    string Id,
    string DisplayName,
    string Category,
    WindowsActionKind Kind,
    MouseButtonId? MouseButton = null,
    IReadOnlyList<ushort>? VirtualKeys = null)
{
    public string SelectionLabel => $"{Category}  |  {DisplayName}";
}
