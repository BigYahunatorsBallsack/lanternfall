Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
public static class SpriteAlphaAudit {
 public static int[] Scan(byte[] pixels, int width, int height, int stride) {
  int minX=width, minY=height, maxX=-1, maxY=-1, minA=255, maxA=0, transparent=0, edge=0;
  for(int y=0;y<height;y++) for(int x=0;x<width;x++) {
   int a=pixels[y*stride+x*4+3];
   if(a<minA) minA=a; if(a>maxA) maxA=a; if(a==0) transparent++;
   if(a>=16) { if(x<minX)minX=x; if(y<minY)minY=y; if(x>maxX)maxX=x; if(y>maxY)maxY=y; if(x==0||y==0||x==width-1||y==height-1)edge++; }
  }
  return new int[]{minX,minY,maxX,maxY,minA,maxA,transparent,edge};
 }
}
'@
$roster = Get-Content roster.json -Raw | ConvertFrom-Json
$results = foreach ($entry in $roster) {
 $filePath = Join-Path (Get-Location) $entry.spriteFile
 if (!(Test-Path -LiteralPath $filePath)) { throw "Missing sprite: $($entry.id)" }
 $bitmap = [System.Drawing.Bitmap]::new($filePath)
 $rectangle = [System.Drawing.Rectangle]::new(0,0,$bitmap.Width,$bitmap.Height)
 $locked = $bitmap.LockBits($rectangle,[System.Drawing.Imaging.ImageLockMode]::ReadOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
 $bytes = [byte[]]::new([Math]::Abs($locked.Stride)*$bitmap.Height)
 [System.Runtime.InteropServices.Marshal]::Copy($locked.Scan0,$bytes,0,$bytes.Length)
 $audit = [SpriteAlphaAudit]::Scan($bytes,$bitmap.Width,$bitmap.Height,$locked.Stride)
 $bitmap.UnlockBits($locked)
 [pscustomobject]@{
  id=$entry.id;category=$entry.category;file=$entry.spriteFile;width=$bitmap.Width;height=$bitmap.Height
  alphaMinimum=$audit[4];alphaMaximum=$audit[5];fullyTransparentPixels=$audit[6];opaqueEdgePixels=$audit[7]
  contentBounds=@{left=$audit[0];top=$audit[1];right=$audit[2];bottom=$audit[3];alphaThreshold=16}
  suggestedFootAnchor=@{x=[Math]::Round((($audit[0]+$audit[2])/2)/$bitmap.Width,6);y=[Math]::Round($audit[3]/$bitmap.Height,6)}
  sha256=(Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash.ToLower()
 }
 $bitmap.Dispose()
}
$results | ConvertTo-Json -Depth 6 | Set-Content validation.json -Encoding utf8
[pscustomobject]@{
 count=$results.Count
 missingTransparency=@($results | Where-Object alphaMinimum -NE 0).Count
 touchingCanvasEdge=@($results | Where-Object opaqueEdgePixels -GT 0 | Select-Object id,opaqueEdgePixels)
 sizes=@($results | Group-Object width,height | Select-Object Name,Count)
} | ConvertTo-Json -Depth 5
