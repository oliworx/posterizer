<?php

$_FILES["if"]["type"]
  or exit("No input file selected!");

$_FILES["if"]["type"] == "application/pdf"
  or exit("Sorry, only PDF files are allowed.");

$_FILES["if"]["size"] <= 1024*1024*10
  or exit("Sorry, maximum allowed file size is 10MB.");

$tmpPoster = $_FILES["if"]["tmp_name"].'_poster';
try {
  $result = system('pdfposter -p 2x2a4 ' . $_FILES["if"]["tmp_name"] . ' ' . $tmpPoster, $resultCode);
} catch (Exception $e) {
  exit('Sorry, there was an error processing your file: ' . $e->getMessage());
} finally {
  unlink($_FILES["if"]["tmp_name"]);
}
if (!file_exists($tmpPoster)) {
  exit("Sorry, something went wrong.");
}

header('Content-Description: File Transfer');
header('Content-Type: application/pdf');
header('Content-Disposition: attachment; filename="Poster_'.$_FILES["if"]["name"].'"');
header('Expires: 0');
header('Cache-Control: private');
header('Content-Length: ' . filesize($tmpPoster));
readfile($tmpPoster);
unlink($tmpPoster);
