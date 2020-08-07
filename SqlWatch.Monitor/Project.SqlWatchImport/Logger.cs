using System;
using System.Diagnostics;
using System.Threading;

namespace SqlWatchImport
{

	internal class Logger
	{

		public static TraceSwitch GeneralTraceSwitch = new TraceSwitch("GeneralTraceSwitch", "Entire Application");

		private static void FormatMessage(string type, string message, ConsoleColor color)
		{

			string output = "";
			string thread = "";

			if (GeneralTraceSwitch.TraceVerbose && type != "")
			{
				thread = "(Thread: " + Thread.CurrentThread.ManagedThreadId + ")";
			}

			output = string.Format("{0:yyyy-MM-dd HH:mm:ss.fff}", DateTime.Now) + " " + type + " " + message + " " + thread;

			Console.ForegroundColor = color;
			Trace.WriteLine(output);
			//Console.ResetColor();

		}

		internal static void LogVerbose(string message)
		{
			if (GeneralTraceSwitch.TraceVerbose)
            {
				string type = "DEBUG";
				FormatMessage(type, message, ConsoleColor.Blue);
			}
		}

		internal static void LogMessage(string message)
		{
			string type = "";
			FormatMessage(type, message, ConsoleColor.White);
		}

		internal static void LogInformation(string message)
		{
			if (GeneralTraceSwitch.TraceInfo)
			{
				string type = "INFO";
				FormatMessage(type, message, ConsoleColor.White);
			}
		}

		internal static void LogSuccess(string message)
		{
			if (GeneralTraceSwitch.TraceInfo)
            {
				string type = "INFO";
				FormatMessage(type, message, ConsoleColor.Green);
			}
		}

		internal static void LogWarning(string message, string error = null)
		{
			if (GeneralTraceSwitch.TraceWarning)
            {
				string type = "WARNING";

				if (error != null)
                {
					message += "\n" + Config.tsplaceholder + "at " + error;
				}
				FormatMessage(type, message, ConsoleColor.Yellow);
			}
		}

		internal static void LogCritical(string message, string error = null, string sql = null)
		{

			// we are going to quit the application if we hit critical error regardless
			// of the trace setting:

			string type = "CRITICAL";

			if (error != null)
			{
				message += "\n" + Config.tsplaceholder + "at " + error;

			}

			if (sql != null)
			{
				message += "\n" + Config.tsplaceholder + sql;
			}

			FormatMessage(type, message, ConsoleColor.Red);
			Config.hasErrors = true;

			Environment.ExitCode = 1;
			Environment.Exit(1);
		}

		internal static void LogError(string message, string error = null, string sql = null)
		{

			if (GeneralTraceSwitch.TraceError)
            {
				string type = "ERROR";

				if (error != null)
				{
					message += "\n" + Config.tsplaceholder + "at " + error;

				}

				if (sql != null)
				{
					message += "\n" + Config.tsplaceholder + sql;
				}

				FormatMessage(type, message, ConsoleColor.Red);
				Config.hasErrors = true;
			}
		}
	}
}
