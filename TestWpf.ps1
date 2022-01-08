<#

https://www.reddit.com/r/PowerShell/comments/n7wcer/wpf_datagrid_file_progress_viewmodel_with/gxgkhx6/
    The ability to handle hyperlinks in a datagrid i.e. opening URLs in the default web browser, and invoking local files in a default application

https://stackoverflow.com/questions/56816597/error-trying-to-implement-ivalueconverter-in-powershell-xaml-gui-script

& C:\Users\HP\Desktop\Powershell\TestWpf.ps1
#>

# $null = [System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
Add-Type -AssemblyName PresentationCore, PresentationFramework

Add-Type -TypeDefinition @"
using System;
using System.Windows.Data;

namespace MyConverter {

    [ValueConversion(typeof(object), typeof(string))]
    public class ConvertLongToFilesize : IValueConverter {
        public object Convert(object value, Type targetType, object parameter, System.Globalization.CultureInfo culture) {
            double num = double.Parse(value.ToString());
            string[] units = new string[] { "B", "KiB", "MiB", "GiB", "TiB", "PiB", "YiB" };
            int unitsIdx = 0;
            while (num > 1024) {
                num /= 1024;
                unitsIdx++;
            }
            //return $"{Math.Round(num, 2)} {units[unitsIdx]}";
            return Math.Round(num, 2).ToString() + " " + units[unitsIdx].ToString();
        }

        public object ConvertBack(object value, Type targetType, object parameter, System.Globalization.CultureInfo culture) {
            // don't intend this to ever be called
            return null;
        }
    }
}
"@ -ReferencedAssemblies PresentationFramework

Add-Type @"
using System;
using System.ComponentModel;
using System.Runtime.CompilerServices;

// observable collection viewmodel
public class HyperlinkViewModel : INotifyPropertyChanged {
    public event PropertyChangedEventHandler PropertyChanged;
    private int _progress;
    private long _size;

    public int Sort { get; set; }
    public string Path { get; set; }

    public int Progress {
        get { return _progress; }
        set {
            _progress = value;
            OnPropertyChanged();
        }
    }

    public long Size {
        get { return _size; }
        set {
            _size = value;
            OnPropertyChanged();
        }
    }

    public string SourceURL { get; set; }

    public void OnPropertyChanged([CallerMemberName]string caller = null) {
        var handler = PropertyChanged;
        if (handler != null) {
            handler(this, new PropertyChangedEventArgs(caller));
        }
    }
}
"@

# init synchronized hashtable
$Sync = [HashTable]::Synchronized(@{})

# init runspace
$Runspace = [RunspaceFactory]::CreateRunspace()
$Runspace.ApartmentState = [Threading.ApartmentState]::STA
$Runspace.ThreadOptions = "ReuseThread"         
$Runspace.Open()

# provide the other thread with the synchronized hashtable (variable shared across threads)
$Runspace.SessionStateProxy.SetVariable("Sync", $Sync)

# utilizing a converter requires that you pull the rather ugly assembly name
$conv = New-Object MyConverter.ConvertLongToFilesize
$ConverterAssemblyName = $conv.GetType().Assembly.FullName.Split(',')[0]

[Xml]$WpfXml = @"
<Window x:Name="WpfRunspaceTemplate" x:Class="WpfApp1.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:WpfApp1"
        xmlns:Converter="clr-namespace:MyConverter;assembly=ConverterAssemblyName"
        mc:Ignorable="d"
        Title="WPF Datagrid File Progress ViewModel with hyperlink demo" 
        WindowStartupLocation="CenterScreen" 
        Visibility="Visible" 
        ResizeMode="CanMinimize" Height="500" Width="600">
    <Window.Resources>
        <Converter:ConvertLongToFilesize x:Key="Convert2Filesize"/>
        <Style TargetType="ProgressBar">
            <Setter Property="Control.Background" Value="#777777" />
            <Setter Property="Control.Foreground" Value="#425595" />
        </Style>
    </Window.Resources>

    <DockPanel>
        <Menu DockPanel.Dock="Top">
            <MenuItem Header="_File">
                <MenuItem
                    x:Name="mnuWindowStart"
                    Header="_Start"/>
                <Separator />
            </MenuItem>
        </Menu>

        <Grid>

            <Grid.RowDefinitions>
                <RowDefinition/>
                <RowDefinition Height="25"/>
                <RowDefinition Height="150"/>
            </Grid.RowDefinitions>

            <!-- 
            https://stackoverflow.com/questions/37379989/how-to-change-the-background-color-of-the-datagrid
            -->
            <DataGrid
                Grid.Row="0"
                Height="Auto"
                x:Name="gridFileListing"
                CanUserReorderColumns="False"
                CanUserResizeColumns="True"
                CanUserResizeRows="False"
                CanUserSortColumns="True"
                CanUserAddRows="False"
                IsReadOnly="True"
                AutoGenerateColumns="False"
                SelectionMode="Single"
                SelectionUnit="FullRow">
                <DataGrid.Resources>
                    <SolidColorBrush x:Key="{x:Static SystemColors.HighlightBrushKey}" Color="LightBlue"/>
                    <SolidColorBrush x:Key="{x:Static SystemColors.InactiveSelectionHighlightBrushKey}" Color="DarkGray"/>
                </DataGrid.Resources>              
                <DataGrid.CellStyle>
                    <Style TargetType="DataGridCell">
                        <Setter Property="BorderThickness" Value="0"/>
                        <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
                    </Style>
                </DataGrid.CellStyle>

                <!--
                columns:
                #   Path    Progress    Size    SourceURL
                -->
                <DataGrid.Columns>
                    <DataGridTextColumn Width="30" Header="#" Binding="{Binding Sort}"/>
                    <DataGridTemplateColumn Width="150" Header="Path">
                        <DataGridTemplateColumn.CellTemplate>
                            <DataTemplate>
                                <TextBlock>
                                    <Hyperlink NavigateUri="{Binding Path}">
                                        <TextBlock Text="{Binding Path}"/>
                                    </Hyperlink>
                                </TextBlock>
                            </DataTemplate>
                        </DataGridTemplateColumn.CellTemplate>
                    </DataGridTemplateColumn>
                    <DataGridTemplateColumn Width="150" Header="Progress" SortMemberPath="Progress" CanUserSort="True">
                        <DataGridTemplateColumn.CellTemplate>
                            <DataTemplate>
                                <Grid>
                                    <ProgressBar
                                        x:Name="ProgressBar"
                                        Value="{Binding Progress}"/>
                                    <TextBlock
                                        Text="{Binding ElementName=ProgressBar, Path=Value, StringFormat={}{0:0}%}"
                                        HorizontalAlignment="Center"
                                        VerticalAlignment="Center"/>
                                </Grid>
                            </DataTemplate>
                        </DataGridTemplateColumn.CellTemplate>
                    </DataGridTemplateColumn>
                    <DataGridTextColumn Width="100" Header="Size" Binding="{Binding Size, Converter={StaticResource Convert2Filesize}}"/>
                    <DataGridTemplateColumn Width="100*" Header="Source URL">
                        <DataGridTemplateColumn.CellTemplate>
                            <DataTemplate>
                                <TextBlock>
                                    <Hyperlink NavigateUri="{Binding SourceURL}">
                                        <TextBlock Text="{Binding SourceURL}"/>
                                    </Hyperlink>
                                </TextBlock>
                            </DataTemplate>
                        </DataGridTemplateColumn.CellTemplate>
                    </DataGridTemplateColumn>
                </DataGrid.Columns>
            </DataGrid>

            <Grid Grid.Row="1">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition/>
                    <ColumnDefinition/>
                    <ColumnDefinition/>
                </Grid.ColumnDefinitions>
                <Button
                    Grid.Column="0"
                    x:Name="btnStart"
                    Content="Start"
                    IsEnabled="True"/>
                <Button
                    Grid.Column="1"
                    x:Name="btnPause"
                    Content="Pause"
                    IsEnabled="False"/>
                <Button
                    Grid.Column="2"
                    x:Name="btnStop"
                    Content="Stop"
                    IsEnabled="False"/>
            </Grid>
            <GroupBox
                Grid.Row="2"
                Header="Log"
                VerticalAlignment="Stretch">
                <ListBox
                    x:Name="lstLog">
                    <ListBox.ContextMenu>
                        <ContextMenu>
                            <MenuItem
                                x:Name="mnuLogCopy"
                                Header="Copy" />
                        </ContextMenu>
                    </ListBox.ContextMenu>
                </ListBox>
            </GroupBox>
        </Grid>
    </DockPanel>
</Window>
"@ -replace "ConverterAssemblyName", $ConverterAssemblyName

<#
https://stackoverflow.com/questions/36676495/make-visual-studio-xaml-output-compatible-to-system-windows-markup-xamlreader
these attributes can disturb powershell's ability to load XAML, so remove them
    Remove the x:Class attribute, since we don't have the corresponding class defined
    Remove the mc:Ignorable attribute, since it can't be resolved
#>
$WpfXml.Window.RemoveAttribute('x:Class')
$WpfXml.Window.RemoveAttribute('mc:Ignorable')

# add namespaces for later use if needed
$WpfNs = New-Object -TypeName Xml.XmlNamespaceManager -ArgumentList $WpfXml.NameTable
$WpfNs.AddNamespace('x', $WpfXml.DocumentElement.x)
$WpfNs.AddNamespace('d', $WpfXml.DocumentElement.d)
$WpfNs.AddNamespace('mc', $WpfXml.DocumentElement.mc)

$Sync.Gui = @{}
$Sync.UserPause = $false
$Sync.UserStop = $false

# function to log text to listbox
$Sync.LogText = {
    param(
        [string]$content,
        [string]$color
    )
    $Sync.Window.Dispatcher.Invoke([Action]{
        $lstItem = New-Object System.Windows.Controls.ListBoxItem -Property @{
            Content = $content
            Foreground = if ($color.Length -eq 0) {"Black"} else {$color}
        }
        $Sync.Gui.lstLog.Items.Add($lstItem)
        $Sync.Gui.lstLog.ScrollIntoView($Sync.Gui.lstLog.Items[$Sync.Gui.lstLog.Items.Count-1])
    })
}


<#
https://stackoverflow.com/questions/36676495/make-visual-studio-xaml-output-compatible-to-system-windows-markup-xamlreader
#>
try {
    $Sync.Window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $WpfXml))
} catch {
    Write-Host $_ -ForegroundColor Red
    Exit
}

#===================================================
# Retrieve a list of all GUI elements
#===================================================
$WpfXml.SelectNodes('//*[@x:Name]', $WpfNs) | ForEach-Object {
    $Sync.Gui.Add($_.Name, $Sync.Window.FindName($_.Name))
}

# bind observable collection to datagrid
$Sync.ViewFiles = New-Object System.Collections.ObjectModel.ObservableCollection[HyperlinkViewModel]
$Sync.Gui.gridFileListing.ItemsSource = $Sync.ViewFiles

#===================================================
# Form element event handlers
#===================================================
$Sync.Gui.mnuLogCopy.add_Click({
    # copy listbox selected item text to clipboard
    Set-Clipboard -Value $Sync.Gui.lstLog.SelectedItem.Content
})

$Sync.Gui.btnPause.add_Click({
    # toggle pause/resume
    $Sync.UserPause = -not $Sync.UserPause
    $Sync.Gui.btnPause.Content = if ($Sync.UserPause) {"Resume"} else {"Pause"}
})

$Sync.Gui.btnStop.add_Click({
    # tell the other thread the user would like to stop
    $Sync.UserStop = $true
})

$StartTask = {
    # init states
    $Sync.Gui.btnStart.IsEnabled = $false
    $Sync.Gui.mnuWindowStart.IsEnabled = $false
    $Sync.Gui.btnPause.IsEnabled = $true
    $Sync.Gui.btnStop.IsEnabled = $true

    # add a script to run in the other thread
    $global:Session = [PowerShell]::Create().AddScript({
        # log start date
        $Sync.LogText.Invoke("Started at $(Get-Date)")

        # dispatcher invoke https://stackoverflow.com/a/15027483
        $Sync.Window.Dispatcher.Invoke([Action]{
            $Sync.ViewFiles.Add((New-Object HyperlinkViewModel -Property @{
                Sort = $Sync.ViewFiles.Count + 1
                Path = "C:\Windows\explorer.exe"
                Size = (Get-Item -LiteralPath "C:\Windows\explorer.exe").Length
                Progress = 0
                SourceURL = "https://duckduckgo.com/"
            }))
        }, "Normal")  # dispatcher priority Normal

        #===================================================
        # Simulate a long-running task
        #===================================================
        while (-not $Sync.UserStop) {
            Start-Sleep -Milliseconds 10

            # sample update the GUI on the main thread
            # from within the runspace session
            $Sync.Window.Dispatcher.Invoke([Action]{
                foreach ($item in $Sync.ViewFiles) {
                    $item.Progress += (Get-Random -Minimum 3 -Maximum 7)
                    if ($item.Progress -gt 100) {
                        $Sync.LogText.Invoke("Item complete", "Green")
                        $item.Progress = 0
                    }
                }
            }, "Normal")

            # handle pause
            while ($Sync.UserPause -and (-not $Sync.UserStop)) {
                Start-Sleep -Seconds 1
            }
        }

        # reset states
        $Sync.Window.Dispatcher.Invoke([Action]{
            $Sync.Gui.btnStart.IsEnabled = $true
            $Sync.Gui.mnuWindowStart.IsEnabled = $true
            $Sync.Gui.btnPause.IsEnabled = $false
            $Sync.Gui.btnStop.IsEnabled = $false
            $Sync.UserStop = $false
            $Sync.UserPause = $false
            $Sync.Gui.btnPause.Content = "Pause"
        })

        # log end date
        $Sync.LogText.Invoke("Finished at $(Get-Date)")
    }, $true)

    # invoke the runspace session created above
    $Session.Runspace = $Runspace
    $global:Handle = $Session.BeginInvoke()
}

$Sync.Gui.mnuWindowStart.add_Click($StartTask)
$Sync.Gui.btnStart.add_Click($StartTask)

#===================================================
# Window events
#===================================================

# $Sync.Window.add_PreviewMouseLeftButtonDown({
# })

$Sync.Window.add_PreviewMouseLeftButtonUp({
    $grid = $Sync.Gui.gridFileListing
    $result = [System.Windows.Media.VisualTreeHelper]::HitTest($grid, $_.GetPosition($grid))
    $element = $result.VisualHit

    if (($null -ne $element) -and ($element.GetType().Name -eq "TextBlock")) {
        if ($null -ne $element.Parent) {
            # handle hyperlink click
            if (($null -ne $element.Parent.Parent) -and ($element.Parent.Parent.GetType().Name -eq "Hyperlink")) {
                $hyperlink = $element.Parent.Parent

                if ($hyperlink.NavigateUri.AbsoluteUri.ToLower().StartsWith("http")) {
                    # open link in default browser
                    Start-Process $hyperlink.NavigateUri.AbsoluteUri
                } elseif (Test-Path -LiteralPath $hyperlink.NavigateUri.OriginalString) {
                    # launch file
                    Invoke-Item -LiteralPath $hyperlink.NavigateUri.OriginalString
                }
            }
        }
    }
})

$Sync.Window.add_Closing({
    # if user triggers app close and runspace session not complete
    if (($null -ne $Session) -and ($Handle.IsCompleted -eq $false)) {
        # alert the user the command is still running
        [Windows.MessageBox]::Show('A command is still running.')
        # prevent exit
        $PSItem.Cancel = $true
    }
})

$Sync.Window.add_Closed({
    # end session and close runspace on window exit
    if ($null -ne $Session) {
        $Session.EndInvoke($Handle)
    }
    
    $Runspace.Close()
})

# display the form
[void]$Sync.Window.ShowDialog()
