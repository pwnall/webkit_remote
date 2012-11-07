(function () {
  var xhr = new XMLHttpRequest();
  xhr.responseType = "blob";
  xhr.onreadystatechange = function () {
    if (xhr.readyState === 4) {
      console.log("Test done");
    }
  };
  xhr.open("GET", "../png/network.png", true);
  xhr.send();
})();
