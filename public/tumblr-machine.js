$(document).ready(function () {
  if (window.Notification && Notification.permission !== 'granted') {
    Notification.requestPermission(function (status) {
      if (Notification.permission !== status) {
        Notification.permission = status;
      }
    });
  }

  // we resize the image widther than the screen
  var containerWidth = $('#posts').innerWidth();
  $('.post').each(function (index, postDom) {
    var post = $(postDom);
    var postWith = post.outerWidth(true);
    if (postWith > containerWidth) {
      var targetWidth = (containerWidth - (postWith - post.width())) + 'px';
      post.css('width', targetWidth);
      post.find('img').css('max-width', targetWidth);
      post.find('.postInfo').css('max-width', targetWidth);
    }
  });

  if (window.Notification && Notification.permission === "granted") {
    var imagesToLoad = 0;
    var allCallbacksAreAdded = false;
    
    var checkIfFinished = function () {
      if (allCallbacksAreAdded && (imagesToLoad == 0)) {
        new Notification('Images loaded');
      }
    };
    var imageLoaded = function () {
      imagesToLoad--;
      checkIfFinished();
    };
    $('img').each(function () {
      imagesToLoad++;
      if (this.complete) {
        imageLoaded();
      } else {
        $(this).on('load', function () {
          imageLoaded()
        });
      }
    });
    allCallbacksAreAdded = true;
    checkIfFinished();
  }
  $('#posts').compactWall($('.post'), {'maxTime': 1000});
});

function editTag(name, value, fetch) {
  $('input[name=tagName]').val(name);
  $('input[name=tagValue]').val(value);
  $('input[name=tagFetch]').attr('checked', fetch == 0);
}

function reblog(id) {
  if (confirm("Are you sure you want to reblog this post ?")) {
    callAndDisplayResult('/reblog/' + id);
  }
}

function seeTags() {
  $("#tags").remove();
  $.get('/tags', function (data) {
    $('body').append(data);
    $(".tagsTable").tablesorter();
  });

}

function seeAllTags() {
  $("#allTags").remove();
  $.get('/all_tags', function (data) {
    $('body').append(data);
    $("#tagsTableOther tr").click(function (e) {
      var children = $(e.currentTarget).children();
      $('input[name=tagName]').val($(children[1]).children()[0].text);
      $('input[name=tagValue]').val(0);
      $('input[name=tagFetch]').attr('checked', false);
    });
  });
}

function callAndDisplayResult(url) {
  $.get(url, function (data) {
    displayMessage(data);
  });
}

function displayMessage(message) {
  var displayResult = function () {
    $('#messages').append('<div id="notice" class="flash">' + message + '</div>');
  };
  if ($('.flash').length == 0) {
    displayResult();
  } else {
    $('.flash').fadeOut(function () {
      $('.flash').remove();
      displayResult();
    });
  }
}
