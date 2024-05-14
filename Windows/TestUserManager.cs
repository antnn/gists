using System;
using System.DirectoryServices.AccountManagement;
using System.Windows;
using System.DirectoryServices;
using System.Threading.Tasks;
using System.Management.Automation;

namespace AddUser.automation
{
    class UserManager {
        static string SecPostfix = "Sec";
        public static async Task<bool> CreateUser(string firstName, string middleName, string lastName,
            string userLogonName, string departament,
            string phone, string address)
        {
            // Creating the PrincipalContext
            return await TaskEx.Run(() =>
            {
                PrincipalContext principalContext = null;
                try
                {
                    principalContext = new PrincipalContext(ContextType.Domain, null, "CN=Users,DC=test,DC=corp");
                }
                catch (Exception e)
                {
                    MessageBox.Show("Ошибка создания PrincipalContext. Исключение: " + e);

                }

                // Check if user object already exists in the store
                UserPrincipal usr = UserPrincipal.FindByIdentity(principalContext, userLogonName);
                if (usr != null)
                {
                    MessageBox.Show(userLogonName + " уже существует. Выберите другое имя пользователя");
                    return false;
                }

                // Create the new UserPrincipal object
                using (var userPrincipal = new UserPrincipal(principalContext))
                {

                    if (lastName != null && lastName.Length > 0)
                        userPrincipal.Surname = lastName;

                    if (firstName != null && firstName.Length > 0)
                        userPrincipal.GivenName = firstName;

                    if (middleName != null && middleName.Length > 0)
                        userPrincipal.MiddleName = middleName;


                    if (phone != null && phone.Length > 0)
                        userPrincipal.VoiceTelephoneNumber = phone;

                    if (userLogonName != null && userLogonName.Length > 0)
                        userPrincipal.SamAccountName = userLogonName;


                    var pwdOfNewlyCreatedUser = "1234567890@pR!";
                    userPrincipal.SetPassword(pwdOfNewlyCreatedUser);

                    userPrincipal.Enabled = true;
                    userPrincipal.ExpirePasswordNow();

                    try
                    {
                        userPrincipal.Save();
                    }
                    catch (Exception e)
                    {
                        MessageBox.Show("Исключение при создании пользователя. " + e);
                        return false;
                    }

                    if (departament != null && departament.Length > 0)
                    {
                        UserManager.AddToDepartment(userPrincipal.Guid, ref departament);
                        UserManager.EnableMailBox(userPrincipal);
                    }
        

                    if (userPrincipal.GetUnderlyingObjectType() == typeof(DirectoryEntry))
                    {
                        DirectoryEntry entry = (DirectoryEntry)userPrincipal.GetUnderlyingObject();
                        if (address != null && address.Length > 0)
                            entry.Properties["streetAddress"].Value = address;
                        try
                        {
                            entry.CommitChanges();
                        }
                        catch (Exception e)
                        {
                            MessageBox.Show("Исключение при создании пользователя. " + e);
                            return false;
                        }
                    }
                    return true;
                }
            });
        }
        public static bool AddToDepartment(Guid? user, ref string groupName) {
            PrincipalContext principalContext = null;
            try
            {
                principalContext = new PrincipalContext(ContextType.Domain, null, "DC=test,DC=corp");
            }
            catch (Exception e)
            {
                MessageBox.Show("Ошибка создания PrincipalContext. Исключение: " + e);
                principalContext.Dispose();
                return false;
            }
         
            var group = GroupPrincipal.FindByIdentity(principalContext, IdentityType.Name, groupName);
            if (group != null)
            {
                group.Members.Add(principalContext, IdentityType.Guid, user.ToString());
                group.Save();
            } else {
                principalContext.Dispose();
                return false;
            }

            var groupSec = GroupPrincipal.FindByIdentity(principalContext, IdentityType.Name, groupName + UserManager.SecPostfix);
            if (groupSec != null)
            {
                groupSec.Members.Add(principalContext, IdentityType.Guid, user.ToString());
                groupSec.Save();
                principalContext.Dispose();
                return true;
            }

            principalContext.Dispose();
            return false;
         }
        public static void EnableMailBox (UserPrincipal user)
        {
            using (var ps = PowerShell.Create())
            {   // Экземпляр Microsoft.Exchange.Management.RecipientTasks.EnableMailbox
                // нельзя инстанцировать, базовый: Cmdlet
                // поэтому через Powershell
                ps.AddScript("Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010");
                ps.AddScript("Enable-Mailbox" +
                " -Identity " + user.Guid.ToString() +
                " -Alias " + user.SamAccountName +
                " -DisplayName " + user.GivenName + " " + user.Surname);
                ps.Invoke();
            }
           
        }
    }
}
