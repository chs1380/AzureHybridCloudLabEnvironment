using Azure;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.Extensions.Logging;
using PcReservationFunctionApp.Dao;
using PcReservationFunctionApp.Helper;
using PcReservationFunctionApp.Model;

namespace PcReservationFunctionApp;

public static class AddSshConnectionFunction
{
    [FunctionName(nameof(AddSshConnectionFunction))]
    public static IActionResult Run(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = null)]
        HttpRequest req,
        ExecutionContext context,
        ILogger log)
    {
        log.LogInformation("AddSshProxyFunction HTTP trigger function processed a request.");

        var status = req.Form["Status"];
        var output = req.Form["Output"];

        log.LogInformation(output);
        var sshConnection = SshConnection.FromJson(output, log);
        if (sshConnection == null) return new OkObjectResult("sshConnection null.");

        var config = new Config(context);
        var sshConnectionDao = new SshConnectionDao(config, log);
        sshConnection.PartitionKey = sshConnection.Location;
        sshConnection.RowKey = sshConnection.Email;
        sshConnection.Status = "Unassigned";
        sshConnection.ETag = ETag.All;

        log.LogInformation(status);
        if (status == "CREATED")
        {
            sshConnectionDao.Upsert(sshConnection);
            log.LogInformation("Done Upsert.");
            return new OkObjectResult(sshConnection);
        }
        if (status == "DELETED" || status == "DELETING")
        {
            sshConnectionDao.Delete(sshConnection);
            log.LogInformation("Deleted.");
            return new OkObjectResult(sshConnection);
        }
        log.LogInformation(sshConnection.ToString());
        return new OkObjectResult($"Status {status} no action.");
    }
}