<?php
$files = glob(__DIR__ . DIRECTORY_SEPARATOR . '*');
$matches = [];

foreach ($files as $path) {
    $name = basename($path);
  if (preg_match('/^\d{8}[^.]*\.(?:html|pdf|txt)$/i', $name)) {
        $matches[] = $name;
    }
}

rsort($matches, SORT_STRING);
?>
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Blog Index</title>
    <link rel="stylesheet" href="style.css">
    <script defer src="main.js"></script>
    <style>
      ul.posts {
        display: grid;
        row-gap: 0.75em;
      }
    </style>
  </head>
  <body>
    <button id="dm" title="Toggle dark mode">&#9681;</button>
    <h1>chris reilly's science blog</h1>
    <h2>posts</h2>
<?php if (count($matches) === 0): ?>
    <p>No matching files found.</p>
<?php else: ?>
    <ul class="posts">
<?php foreach ($matches as $file): ?>
      <li><a href="<?= htmlspecialchars($file, ENT_QUOTES, 'UTF-8') ?>"><?= htmlspecialchars($file, ENT_QUOTES, 'UTF-8') ?></a></li>
<?php endforeach; ?>
    </ul>
<?php endif; ?>
  </body>
</html>
