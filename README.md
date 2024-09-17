# PTX System

Beware: work in progress!
Especially the javadoc is not completely up-to-date... (waiting for the next realease to update it)

This library has been created in the context of [Papertronics](papertronics.org/en/) (Jérémie Cortial & Roman Miletitch). We wanted to have an easy way to interact with our drawing, we didn't find one, so we created it. And now we opened it up to the world so we're super curious to see what will be done with it!

This library aims at giving you descriptors of any drawing you would feed it (works better with flat tints). Once you have those descriptors (shape, color, size, countour, surface...) it's up to you to create behaviors associated with them. You want your player to be able to jump on green shapes? Maybe he should avoid the red one... And clusters of yellow shapes would be bonuses while big stand alone yellow shapes would be portals? Yep, you can have it all here :)

On top of that, this library deals with all the optical shenanigans necessary for an easy process. From capturing your image from a camera to project it on top of your drawing, everything should be here. We even added on top an interface to make the calibration process easier.

If you're getting started, best would be to check our [intro on wiki](https://github.com/zharkov/ptx_system/wiki). If you want to dig deeper, then you should go explore our (need to be updated, be still good enough) [java doc](http://zharkov.github.io/ptx_system). If you have any questions, don't hesitate to contact us, would that be through github or from our website.

For now, the library is an ensemble of file to use in Processing. First thing in the todo list is to transform it into a full-fedged Processing Library. Another version exist for C++ (used in our team with Cinder library), so if it's more your alley, be sure to ask us for this working-but-less-accessible version.
