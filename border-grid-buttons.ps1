<#
https://stackoverflow.com/questions/36676495/make-visual-studio-xaml-output-compatible-to-system-windows-markup-xamlreader

#>
$null = [System.Reflection.Assembly]::LoadWithPartialName('presentationframework')

$NodeReader = New-Object System.Xml.XmlNodeReader $([xml]@'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
    xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    xmlns:local="clr-namespace:ExampleWin"
    Title="Window" Height="200" Width="200" ToolTip="Tooltip" Topmost="True" WindowStyle="None" AllowsTransparency="True" Background="Transparent" ResizeMode="CanResizeWithGrip">

    <Border 
        BorderBrush="#FF000000" 
        BorderThickness="1,1,1,1" 
        CornerRadius="5,5,5,5" 
        UseLayoutRounding="True">
        
        <!-- -->

        <Grid>
            <Grid.ColumnDefinitions>
                <ColumnDefinition/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <Label x:Name="Backdrop" Grid.ColumnSpan="2" Content="Label" Margin="0,0,0,0" Foreground="{x:Null}" Background="#FFAD3838"/>


            <Button x:Name="Button1" Grid.Column="0" Content="" Margin="1" BorderThickness="0" Background="#FF3B87BD"/>
            <Button x:Name="Button2" Grid.Column="1" Content="" Margin="1" BorderThickness="0" Background="#FF59B483"/>
        </Grid>

    </Border>
</Window>
'@)

$Window = [System.Windows.Markup.XamlReader]::Load($NodeReader)
$Window.ShowDialog()
