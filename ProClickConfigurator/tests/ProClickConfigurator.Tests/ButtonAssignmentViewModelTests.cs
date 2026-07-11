using ProClickConfigurator.Core.Models;
using ProClickConfigurator.Core.ViewModels;

namespace ProClickConfigurator.Tests;

public sealed class ButtonAssignmentViewModelTests
{
    [Fact]
    public void LeftPrimaryActionIsLockedWhileHyperShiftRemainsConfigurable()
    {
        var changes = 0;
        var assignment = new ButtonAssignmentViewModel(
            MouseButtonId.Left,
            WindowsActionCatalog.Get(WindowsActionCatalog.DisabledId),
            WindowsActionCatalog.Get(WindowsActionCatalog.PassthroughId),
            () => changes++);

        Assert.False(assignment.CanAssignPrimaryAction);
        Assert.True(assignment.IsPrimaryActionLocked);
        Assert.Equal(WindowsActionCatalog.LeftClickId, assignment.PrimaryAction.Id);

        assignment.PrimaryAction = WindowsActionCatalog.Get("media.play-pause");
        assignment.HyperShiftAction = WindowsActionCatalog.Get("media.play-pause");

        Assert.Equal(WindowsActionCatalog.LeftClickId, assignment.PrimaryAction.Id);
        Assert.Equal("media.play-pause", assignment.HyperShiftAction.Id);
        Assert.Equal(1, changes);
    }
}
