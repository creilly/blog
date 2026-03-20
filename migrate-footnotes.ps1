param(
  [string]$Path = ".",
  [switch]$IncludeBackups,
  [switch]$WriteBackup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-AttrValue {
  param([string]$Attrs, [string]$Name)
  $m = [regex]::Match($Attrs, "\b$Name=\"([^\"]*)\"", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if ($m.Success) { return $m.Groups[1].Value }
  return $null
}

function Set-Or-ReplaceAttr {
  param([string]$Attrs, [string]$Name, [string]$Value)
  if ([regex]::IsMatch($Attrs, "\b$Name=\"[^\"]*\"", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
    return [regex]::Replace($Attrs, "\b$Name=\"[^\"]*\"", "$Name=\"$Value\"", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  }
  return ($Attrs.TrimEnd() + " $Name=\"$Value\"")
}

function Remove-Attr {
  param([string]$Attrs, [string]$Name)
  return [regex]::Replace($Attrs, "\s+\b$Name=\"[^\"]*\"", "", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

function Ensure-FnClass {
  param([string]$Attrs)
  $classVal = Get-AttrValue -Attrs $Attrs -Name "class"
  if ($null -eq $classVal) {
    return ($Attrs.TrimEnd() + ' class="fn"')
  }

  $parts = $classVal -split "\s+" | Where-Object { $_ }
  if ($parts -notcontains "fn") { $parts += "fn" }
  $newClass = ($parts -join " ")
  return Set-Or-ReplaceAttr -Attrs $Attrs -Name "class" -Value $newClass
}

$optI = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
$optIS = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline

$files = Get-ChildItem -Path $Path -Filter *.html -File
if (-not $IncludeBackups) {
  $files = $files | Where-Object { $_.Name -notmatch '\.backup\.html$' }
}

foreach ($file in $files) {
  $content = Get-Content -Path $file.FullName -Raw

  # Ensure the notes container uses section.ref.
  $content = [regex]::Replace($content, '<section>\s*(?=<p\s+id="fn)', '<section class="ref">', $optI)

  # Normalize note IDs back to fn* if they were migrated the opposite way.
  $content = [regex]::Replace($content, '<p([^>]*?)\sid="ref([^\"]+)"', '<p$1 id="fn$2"', $optI)

  # Remove static backlinks and legacy leading counters inside note paragraphs.
  $content = [regex]::Replace($content, '\s*<a\s+href="#ref[^\"]*"\s*>\s*↩\s*</a>', '', $optI)
  $content = [regex]::Replace($content, '(<p[^>]*\sid="fn[^\"]+"[^>]*>\s*)(?:\[?\d+\]?(?:[:.])\s*)', '$1', $optI)

  # Remove manual <sup> wrappers around fn citations.
  $content = [regex]::Replace(
    $content,
    '<sup>\s*(<a[^>]*\bclass="[^\"]*\bfn\b[^\"]*"[^>]*>.*?</a>)\s*</sup>',
    '$1',
    $optIS
  )

  # Canonicalize every fn citation anchor to: class fn, id ref* OR data-fn, no href, text '*'.
  $content = [regex]::Replace(
    $content,
    '<a(?<attrs>[^>]*)>(?<inner>.*?)</a>',
    {
      param($m)
      $attrs = $m.Groups['attrs'].Value
      $inner = $m.Groups['inner'].Value

      $classVal = Get-AttrValue -Attrs $attrs -Name 'class'
      $idVal = Get-AttrValue -Attrs $attrs -Name 'id'
      $hrefVal = Get-AttrValue -Attrs $attrs -Name 'href'
      $dataFn = Get-AttrValue -Attrs $attrs -Name 'data-fn'

      $isFnClass = $false
      if ($classVal) {
        $isFnClass = ($classVal -split "\s+" | Where-Object { $_ -eq 'fn' }).Count -gt 0
      }
      $isOldRef = ($idVal -and $idVal.StartsWith('ref') -and $hrefVal -and $hrefVal.StartsWith('#fn'))

      if (-not ($isFnClass -or $isOldRef)) {
        return $m.Value
      }

      $key = $null
      if ($dataFn) {
        $key = $dataFn
      } elseif ($idVal -and $idVal.StartsWith('ref')) {
        $key = $idVal.Substring(3)
      } elseif ($idVal -and $idVal.StartsWith('fn')) {
        $key = $idVal.Substring(2)
      } elseif ($hrefVal -and $hrefVal.StartsWith('#fn')) {
        $key = $hrefVal.Substring(3)
      }

      if (-not $key) {
        return $m.Value
      }

      $attrs = Ensure-FnClass -Attrs $attrs
      $attrs = Remove-Attr -Attrs $attrs -Name 'href'

      # Prefer id="ref*" for primary refs; a later pass converts duplicates to data-fn.
      $attrs = Set-Or-ReplaceAttr -Attrs $attrs -Name 'id' -Value ("ref" + $key)

      return "<a$attrs>*</a>"
    },
    $optIS
  )

  # Fix duplicate citation IDs by converting later duplicates to data-fn="key".
  $seen = @{}
  $content = [regex]::Replace(
    $content,
    '<a(?<attrs>[^>]*\bclass="[^\"]*\bfn\b[^\"]*"[^>]*)>\*</a>',
    {
      param($m)
      $attrs = $m.Groups['attrs'].Value
      $idVal = Get-AttrValue -Attrs $attrs -Name 'id'
      $dataFn = Get-AttrValue -Attrs $attrs -Name 'data-fn'

      $key = $null
      if ($dataFn) {
        $key = $dataFn
      } elseif ($idVal -and $idVal.StartsWith('ref')) {
        $key = $idVal.Substring(3)
      }

      if (-not $key) {
        return $m.Value
      }

      if ($seen.ContainsKey($key)) {
        $attrs = Remove-Attr -Attrs $attrs -Name 'id'
        $attrs = Set-Or-ReplaceAttr -Attrs $attrs -Name 'data-fn' -Value $key
      } else {
        $seen[$key] = $true
      }

      return "<a$attrs>*</a>"
    },
    $optIS
  )

  if ($WriteBackup) {
    $backup = "$($file.FullName).pre-migrate.bak"
    [System.IO.File]::WriteAllText($backup, (Get-Content -Path $file.FullName -Raw), [System.Text.Encoding]::UTF8)
  }

  [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.Encoding]::UTF8)
  Write-Host "Migrated $($file.Name)"
}
