using ProClickConfigurator.Core.Protocol;

namespace ProClickConfigurator.Tests;

public sealed class RazerReportTests
{
    [Fact]
    public void CreateBuildsExpectedBatteryRequest()
    {
        var report = RazerReport.Create(
            transactionId: 0x1F,
            commandClass: 0x07,
            commandId: 0x80,
            dataSize: 0x02);

        var bytes = report.ToArray();

        Assert.Equal(RazerReport.Size, bytes.Length);
        Assert.Equal(0x1F, bytes[1]);
        Assert.Equal(0x02, bytes[5]);
        Assert.Equal(0x07, bytes[6]);
        Assert.Equal(0x80, bytes[7]);
        Assert.Equal(0x85, bytes[88]);
    }

    [Fact]
    public void ParseAcceptsCapturedBatteryResponse()
    {
        var bytes = new byte[RazerReport.Size];
        bytes[0] = (byte)RazerCommandStatus.Successful;
        bytes[1] = 0x1F;
        bytes[5] = 0x02;
        bytes[6] = 0x07;
        bytes[7] = 0x80;
        bytes[8] = 0x00;
        bytes[9] = 0xFB;
        bytes[88] = 0x7E;

        var report = RazerReport.Parse(bytes);

        Assert.Equal(RazerCommandStatus.Successful, report.Status);
        Assert.Equal(0x1F, report.TransactionId);
        Assert.Equal(0xFB, report.Arguments[1]);
    }

    [Fact]
    public void ParseRejectsInvalidChecksum()
    {
        var bytes = RazerReport.Create(0x1F, 0x07, 0x80, 0x02).ToArray();
        bytes[88] ^= 0x01;

        var exception = Assert.Throws<RazerProtocolException>(() => RazerReport.Parse(bytes));

        Assert.Contains("checksum", exception.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void CreateRejectsArgumentsLargerThanDeclaredPayload()
    {
        Assert.Throws<ArgumentException>(
            () => RazerReport.Create(0x1F, 0x04, 0x85, 0x01, [0x01, 0x02]));
    }
}
