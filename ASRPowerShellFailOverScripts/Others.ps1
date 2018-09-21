
#region Read data from Excel Sheet

    #Declare the file path and sheet name
        $file = "C:\Users\MyVM\Desktop\DMSASRTemplateV1.0\ConfigFile.xlsx"
        $sheetName = "config"

    #Create an instance of Excel.Application and Open Excel file
        $objExcel = New-Object -ComObject Excel.Application
        $workbook = $objExcel.Workbooks.Open($file)
        $sheet = $workbook.Worksheets.Item($sheetName)
        $objExcel.Visible=$false
    #Count max row
        $rowMax = ($sheet.UsedRange.Rows).count
    #Declare the starting positions
        $rowName,$colName = 1,1
        $rowValue,$colValue = 1,2

        $hcname=@{}
    #loop to get values and store it
        for ($i=1; $i -le $rowMax-1; $i++)
        {
            $name = $sheet.Cells.Item($rowName+$i,$colName).text
            $value = $sheet.Cells.Item($rowValue+$i,$colValue).text
            $hcname[$name]=$value
        }
        $hcname.name3

    #close excel file
        $objExcel.quit()

#endregion


#region Read data from csv file
    $cname = Import-CSV -Path "C:\Users\MyVM\Desktop\Ftest\ConfigFile.csv"

    $hcname=@{}
    foreach($r in $cname)
    {

        $hcname[$r.Name]=$r.Value
    } 
    $hcname.name1

#endregion