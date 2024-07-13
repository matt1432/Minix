{
  buildGoModule,
  curseforge-server-downloader-src,
  ...
}:
buildGoModule {
  pname = "curseforge-server-downloader";
  version = "0pre+" + curseforge-server-downloader-src.shortRev;

  src = curseforge-server-downloader-src;
  doCheck = false;
  vendorHash = null;
}
