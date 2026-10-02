using System.Diagnostics;

namespace BdVoluntariado;

static class Program
{
    [STAThread]
    static void Main()
    {
        var dir = AppContext.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        // Si el exe está en tools\launcher\bin\..., subir hasta la raíz del proyecto
        // En distribución el exe vive junto a iniciar-app.bat
        var bat = FindIniciarApp(dir);
        if (bat == null)
        {
            MessageBox.Show(
                "No encuentro iniciar-app.bat.\n\nColoca \"BD Voluntariado.exe\" en la carpeta del proyecto (junto a iniciar-app.bat).",
                "BD Voluntariado",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
            return;
        }

        var workDir = Path.GetDirectoryName(bat)!;
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = bat,
                WorkingDirectory = workDir,
                UseShellExecute = true,
            });
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                $"No se pudo iniciar la aplicación:\n{ex.Message}",
                "BD Voluntariado",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }
    }

    static string? FindIniciarApp(string startDir)
    {
        var dir = new DirectoryInfo(startDir);
        for (var i = 0; i < 6 && dir != null; i++)
        {
            var candidate = Path.Combine(dir.FullName, "iniciar-app.bat");
            if (File.Exists(candidate)) return candidate;
            dir = dir.Parent;
        }
        return null;
    }
}
