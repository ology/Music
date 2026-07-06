document.addEventListener("touchstart", function() {},false);
let mybutton = document.getElementById("topBtn");
window.onscroll = function() {scrollFunction()};
function scrollFunction() {
  if (document.body.scrollTop > 200 || document.documentElement.scrollTop > 200) {
    mybutton.style.display = "block";
  } else {
    mybutton.style.display = "none";
  }
}
function topFunction() {
  document.body.scrollTop = 0;
  document.documentElement.scrollTop = 0;
}
function playSoundAndRedirect(audioId, url) {
    var audio = document.getElementById(audioId);
    audio.play();

    audio.onended = function() {
        window.location.href = url;
    };
}
function goToAnchor(anchorId) {
  window.location.hash = anchorId;
}
// Accordion drop-down
var acc = document.getElementsByClassName("accordion");
var i;

for (i = 0; i < acc.length; i++) {
  acc[i].addEventListener("click", function() {
    this.classList.toggle("active");
    var accordionContent = this.nextElementSibling;
    if (accordionContent.style.maxHeight){
      accordionContent.style.maxHeight = null;
    } else {
      accordionContent.style.maxHeight = accordionContent.scrollHeight + "px";
    } 
  });
}
// LCARS keystroke sound (not to be used with hyperlinks)
  const LCARSkeystroke = document.getElementById('LCARSkeystroke');
  const allPlaySoundButtons = document.querySelectorAll('.playSoundButton');
  allPlaySoundButtons.forEach(button => {
    button.addEventListener('click', function() {
      LCARSkeystroke.pause();
      LCARSkeystroke.currentTime = 0; // Reset to the beginning of the sound
      LCARSkeystroke.play();
    });
  });