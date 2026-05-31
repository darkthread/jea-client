using System.Collections.ObjectModel;
using System.Management.Automation;
using System.Management.Automation.Remoting;
using System.Management.Automation.Runspaces;
using System.Security;

string computerName = "pdc";
string configurationName =  "JEALabEndpoint";


WSManConnectionInfo connectionInfo = new()
{
	ComputerName = computerName,
    // Credential = new PSCredential(userName, ReadPassword()),
	Credential = null, // Use current user credentials
	AuthenticationMechanism = AuthenticationMechanism.Default,
	ShellUri = "http://schemas.microsoft.com/powershell/Microsoft.PowerShell",
};
connectionInfo.SetSessionOptions(new PSSessionOption());

// This is the key JEA part: connect to the constrained endpoint.
connectionInfo.AppName = "WSMAN";
connectionInfo.ShellUri = $"http://schemas.microsoft.com/powershell/{configurationName}";

using Runspace runspace = RunspaceFactory.CreateRunspace(connectionInfo);

try
{
	runspace.Open();
	Console.WriteLine($"Connected to JEA endpoint '{configurationName}' on '{computerName}'.");

	using PowerShell ps = PowerShell.Create();
	ps.Runspace = runspace;

	Console.WriteLine("Allowed commands in this JEA endpoint:");
	ps.AddCommand("Get-Command");
	Collection<PSObject> commands = ps.Invoke();

	foreach (PSObject item in commands)
	{
		Console.WriteLine(item?.ToString());
	}

	if (ps.HadErrors)
	{
		Console.WriteLine("Get-Command returned errors:");
		foreach (ErrorRecord error in ps.Streams.Error)
		{
			Console.WriteLine(error.ToString());
		}
	}

	ps.Commands.Clear();
	ps.Streams.ClearStreams();

	Console.WriteLine();
	Console.WriteLine("Sample allowed command: Get-Service -Name Spooler");
	ps.AddCommand("Get-Service").AddParameter("Name", "Spooler");
	Collection<PSObject> services = ps.Invoke();

	foreach (PSObject item in services)
	{
		Console.WriteLine(item?.ToString());
	}

	if (ps.HadErrors)
	{
		Console.WriteLine("Get-Service returned errors:");
		foreach (ErrorRecord error in ps.Streams.Error)
		{
			Console.WriteLine(error.ToString());
		}
	}
}
catch (Exception ex)
{
	Console.WriteLine($"JEA connection failed: {ex.Message}");
}


/*
static SecureString ReadPassword()
{
	SecureString securePassword = new();

	while (true)
	{
		ConsoleKeyInfo key = Console.ReadKey(intercept: true);

		if (key.Key == ConsoleKey.Enter)
		{
			break;
		}

		if (key.Key == ConsoleKey.Backspace && securePassword.Length > 0)
		{
			securePassword.RemoveAt(securePassword.Length - 1);
			continue;
		}

		if (!char.IsControl(key.KeyChar))
		{
			securePassword.AppendChar(key.KeyChar);
		}
	}

	securePassword.MakeReadOnly();
	return securePassword;
}
*/