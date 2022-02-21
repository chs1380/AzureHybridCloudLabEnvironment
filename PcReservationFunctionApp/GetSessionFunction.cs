using System;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.Extensions.Logging;
using System.Threading.Tasks;
using PcReservationFunctionApp.Model;

namespace PcReservationFunctionApp
{
    // ReSharper disable once UnusedMember.Global
    public static class GetSessionFunction
    {
        [FunctionName(nameof(GetSessionFunction))]
        // ReSharper disable once UnusedMember.Global
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = null)] HttpRequest req,
            ILogger log)
        {
            log.LogInformation("GetSessionFunction HTTP trigger function processed a request.");

            var computer = new Computer
            {
                Location = req.Query["Location"],
                IpAddress = req.Query["IpAddress"],
                MachineName = req.Query["MachineName"],
                DeviceId = req.Query["DeviceId"],
                MacAddress = req.Query["MacAddress"],
                IsConnected = Convert.ToBoolean(req.Query["IsConnected"]),
                LastErrorMessage = req.Query["LastErrorMessage"],
            };

            log.LogInformation(computer.ToString());
            var session = new Common.Model.Session(ipAddress: "18.236.231.69", port: 2222, username: "bastion", password: "q1Hf82IasE4TlsOkncT&");

            return new OkObjectResult(session.ToJson());
        }
    }
}