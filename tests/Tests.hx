package ;

import issues.Issue49;
import issues.Issue44;

import tink.state.*;
import js.Browser.*;
import coconut.ui.*;
import coconut.data.*;
import coconut.data.Value;
import coconut.Ui.hxx;
using tink.CoreApi;

class Tests extends haxe.unit.TestCase {

  static var entries = [];
  static public function log(msg:String, ?pos:haxe.PosInfos)
    entries.push('${pos.className}:$msg');

  function expectLog(expected:Array<String>, ?pos:haxe.PosInfos)
    assertEquals(expected.join('\n'), entries.splice(0, entries.length).join('\n'), pos);

  override function setup() {
    document.body.innerHTML = '';
  }

  static inline function q(s:String)
    return document.querySelector(s);

  static function qs(s:String) {
    var ret:Array<js.html.Element> = cast document.querySelectorAll(s);
    return [for (x in ret) x];
  }

  static inline function mount(o) {
    var wrapper = document.createElement('wrapper-element');
    document.body.appendChild(wrapper);
    coconut.ui.Renderer.mount(wrapper, o);
  }

  function testNested() {
    var s = new State('foo');
    var foobar = new FooBar();
    mount(hxx('<Nestor plain="yohoho" inner={s.value} {...foobar} />'));

    Renderer.updateAll();

    var beforeOuter = Nestor.redraws,
        beforeInner = Example4.redraws;

    s.set('bar');

    Renderer.updateAll();

    assertEquals(beforeOuter, Nestor.redraws);
    assertEquals(beforeInner + 1, Example4.redraws);
  }

  function testSlot() {
    var s = new coconut.ui.tools.Slot(this),
        s1 = new State(0),
        s2 = new State(1000);
    var log = [];
    s.observe().bind(log.push);
    s.setData(Observable.const(42));
    assertEquals('', log.join(','));
    Renderer.updateAll();
    assertEquals('42', log.join(','));
    s.setData(Observable.const(0));
    Renderer.updateAll();
    assertEquals('42,0', log.join(','));
    s.setData(s1);
    Renderer.updateAll();
    assertEquals('42,0', log.join(','));
    s1.set(1000);
    Renderer.updateAll();
    assertEquals('42,0,1000', log.join(','));
    s.setData(s2);
    Renderer.updateAll();
    assertEquals('42,0,1000', log.join(','));

    s1.set(1001);
    s2.set(1002);
    Renderer.updateAll();
    assertEquals('42,0,1000,1002', log.join(','));
  }

  function testCustom() {
    var s = new State(4);

    mount(hxx('<Example key={s} foo={s} bar={s} />'));
    mount(hxx('<Example foo={s} bar={s} />'));

    assertEquals('4', q('.foo').innerHTML);
    assertEquals('4', q('.bar').innerHTML);

    s.set(5);
    Renderer.updateAll();

    assertEquals('5', q('.foo').innerHTML);
    assertEquals('5', q('.bar').innerHTML);
  }

  function testSlotCache() {
    var s = new State(42);
    mount(hxx('
      <Example6>
        <div data-id={s.value}>
          <Example6>
            <if {s.value > 12}>
              <Example4 value={Std.string(s.value)} />
            </if>
          </Example6>
        </div>
      </Example6>
    '));
    var elt = q('.example4');
    var id = elt.getAttribute('data-id');
    assertTrue(id != null);
    s.set(17);
    Renderer.updateAll();
    assertEquals(elt, q('.example4'));
    assertEquals(id, elt.getAttribute('data-id'));
    assertEquals('17', elt.innerHTML);
  }

  function testCache() {

    var s = new State('42');

    function render(value:String):RenderResult
      return hxx('<Example4 key={"42"} value={value} />');

    mount(hxx('
      <Example5 data={s.value}>
        <renderData>
          {render(data)}
        </renderData>
      </Example5>
    '));
    var id = q('.example4').getAttribute('data-id');
    assertTrue(id != null);
    assertEquals('42', q('.example4').innerHTML);
    s.set('321');
    Renderer.updateAll();
    assertEquals('321', q('.example4').innerHTML);
    assertEquals(id, q('.example4').getAttribute('data-id'));

  }

  function testControlled() {
    mount(hxx('<ControlledCounter id="counter1"/>'));
    assertEquals('0', q('#counter1').innerHTML);
    click('#counter1');
    assertEquals('1', q('#counter1').innerHTML);

    var f = new Foo({ foo: 42 });

    mount(hxx('<ControlledCounter id="counter2" count=${f.foo} />'));
    assertEquals('42', q('#counter2').innerHTML);
    click('#counter2');
    assertEquals('43', q('#counter2').innerHTML);

    mount(hxx('<KeyPad />'));
    assertEquals(null, q('button.selected[data-value="1"]'));
    click('button[data-value="1"]');
    assertEquals('1', q('button.selected[data-value="1"]').innerHTML);
  }

  static function click(selector) {
    q(selector).click();
    Renderer.updateAll();
  }

  function testIssue49() {
    mount(Issue49.buttons());
    assertEquals('DEFAULT', q('span').innerHTML);
  }

  function testModel() {
    var model = new Foo({ foo: 4 });

    var e = null;
    mount(hxx('<Example2 ref={function (inst) e = inst} model={model} />'));

    assertEquals('4', q('.foo').innerHTML);
    assertEquals('4', q('.bar').innerHTML);
    assertEquals('0', q('.baz').innerHTML);

    model.foo = 5;
    Renderer.updateAll();
    assertEquals('5', q('.foo').innerHTML);
    assertEquals('5', q('.bar').innerHTML);

    e.baz = 42;
    Renderer.updateAll();
    assertEquals('42', q('.baz').innerHTML);
  }

  function testModelInCustom() {

    var variants = [
      function (model:Foo) return hxx('<Example foo={model.foo} {...model} />'),
      function (model:Foo) return hxx('<Example foo={model.foo} {...model} bar={model.bar} />')
    ];
    for (render in variants) {
      var model = new Foo({ foo: 4 });
      mount(render(model));

      assertEquals('4', q('.foo').innerHTML);
      assertEquals('4', q('.bar').innerHTML);

      model.foo = 5;
      Renderer.updateAll();
      assertEquals('5', q('.foo').innerHTML);
      assertEquals('5', q('.bar').innerHTML);

      setup();
    }

  }

  function testIssue31() {
    var counter = new State(0),
        btn1 = null,
        btn2 = null;

    mount(hxx('
      <Isolated>
        <div>
          <span>${counter.value}</span>
          <SimpleButton ref={function (e) btn1 = e} onclick=${counter.set(counter.value + 1)}>Yay</SimpleButton>
          <SimpleButton ref={function (e) btn2 = e} onclick=${counter.set(counter.value + 1)}>${Std.string(counter.value)}</SimpleButton>
        </div>
      </Isolated>
    '));


    assertEquals(1, btn1.renderCount);
    assertEquals(1, btn2.renderCount);
    q('button').click();
    Observable.updateAll();
    assertEquals(1, btn1.renderCount);
    assertEquals(2, btn2.renderCount);

    setup();
    var fn:Void->Void = null;

    var button:SimpleButton = null;
    var ref = function (v) button = v;
    mount(hxx('<SimpleButton ref={ref} onclick=${fn}>Exploded</SimpleButton>'));
    try {
      button.onclick();
      assertTrue(false);
    }
    #if debug
    catch (e:String)
      assertEquals('mandatory attribute onclick of <SimpleButton/> was set to null', e);
    #else
    catch (e:Dynamic) {

    }
    #end
  }

  function testSnapshots() {
    var state = new State(123);
    mount(hxx('<Snapshotter value=${state.value} />'));
    state.set(321);
    Observable.updateAll();
    expectLog(['Snapshotter:123']);
  }

  function testViewDidRender() {
    var state = new State(123);
    mount(hxx('<DidRender counter=${state.value} />'));
    state.set(321);
    Observable.updateAll();
    expectLog(['DidRender:true', 'DidRender:false']);
  }

  function testMisc() {//horay for naming!

    var r = new Rec({ foo: 42, bar: 0 }),
        inst = new Inst({}),
        instRef:Inst = null,
        blargh:Blargh = null;

    mount(hxx('
      <Blargh ref={function (v) blargh = v}>
        <blub>
          Foo: {foo}
          <button onclick={r.update({ foo: r.foo + 1})}>{r.foo}</button>
          <Btn onclick={{ var x = 1 + Std.random(10); function () r.update({ foo: r.foo + x}); }} />
          <if {r.foo == 42}>
            <video muted></video>
          <else>
            <video>DIV</video>
          </if>
          <hr/>
          ${inst#if react .reactify()#end}
          <Outer>YEAH ${r.bar}</Outer>
          <Inst ref={function (v) instRef = v} />
        </blub>
      </Blargh>
    '));

    expectLog([
      'Outer:render',
      'Inner:render',
      'Inst:mounted',
      'Inst:mounted',
    ]);

    assertFalse(blargh.hidden);
    assertFalse(instRef == null);
    #if !react
    assertEquals('I am native!', q('.native-element').innerHTML);
    #end
    assertEquals(0, inst.count);
    assertEquals(0, instRef.count);

    for (btn in qs('.inst>button'))
      btn.click();

    assertEquals(1, inst.count);
    assertEquals(1, instRef.count);

    q('.hide-blargh').click();
    Renderer.updateAll();

    expectLog([
      'Inst:unmounting',
      'Inst:unmounting',
    ]);

    assertTrue(instRef == null);
    assertTrue(blargh.hidden);

    blargh.hidden = false;
    Renderer.updateAll();

    expectLog([
      'Outer:render',
      'Inner:render',
      'Inst:mounted',
      'Inst:mounted',
    ]);

    assertEquals(1, inst.count);
    assertEquals(0, instRef.count);

    #if !react
    r.update({ bar: r.bar + 1 });
    Renderer.updateAll();
    expectLog([
      'Outer:render',
      'Inner:render',
      'Inner:updated',
      'Outer:updated',
    ]);
    #end
  }

  function testTodo() {

    var desc = new State('test'),
        done = new State(false);

    mount(hxx('<TodoItemView completed={done} description={desc} onedit={desc.set} ontoggle={done.set} />'));
    var toggle:js.html.InputElement = cast q('input[type="checkbox"]');
    var edit:js.html.InputElement = cast q('input[type="text"]');
    assertFalse(toggle.checked);
    toggle.click();
    assertTrue(done);
    assertEquals('test', edit.value);
    desc.set('foo');
    assertEquals('test', edit.value);
    Renderer.updateAll();
    assertEquals('foo', edit.value);
    #if !react
    edit.value = "bar";
    edit.dispatchEvent(new js.html.Event("change"));//gotta love this
    assertEquals('bar', desc);
    #end
  }

  function testPropViewReuse() {
    var states = [for (i in 0...10) new State(i)];
    var models = [for (s in states) { foo: s.observe() , bar: s.value }];
    var list = new ListModel({ items: models });

    var redraws = Example.redraws;

    var before = Example.created.length;
    mount(hxx('<ExampleListView list={list} />'));
    assertEquals(before + 10, Example.created.length);

    var before = Example.created.length;
    list.items = models;
    Renderer.updateAll();
    assertEquals(before, Example.created.length);

    list.items = models.concat([for (m in models) { bar: m.bar, foo: m.foo }]);
    Renderer.updateAll();
    assertEquals(before + 10, Example.created.length);
    assertEquals(redraws + 20, Example.redraws);

    states[0].set(100);
    Renderer.updateAll();

    assertEquals(redraws + 22, Example.redraws);

    list.items = models;
    Renderer.updateAll();

    assertEquals(redraws + 22, Example.redraws);
  }

  function testRootSwitch() {
    mount(hxx('<MyView />'));
    assertEquals('One', q('div').innerHTML);
  }

  function testModelViewReuse() {

    var models = [for (i in 0...10) new Foo({ foo: i })];
    var list = new ListModel({ items: models });

    var redraws = Example2.redraws;

    var before = Example2.created.length;
    mount(hxx('<FooListView list={list} />'));
    assertEquals(before + 10, Example2.created.length);

    var before = Example2.created.length;
    list.items = models;
    Renderer.updateAll();
    assertEquals(before, Example2.created.length);

    list.items = models.concat(models);
    Renderer.updateAll();
    assertEquals(before + 10, Example2.created.length);
    assertEquals(redraws + 20, Example2.redraws);

  }

  static function main() {

    var runner = new haxe.unit.TestRunner();
    runner.add(new Tests());

    travix.Logger.exit(
      if (runner.run()) 0
      else 500
    );
  }
}

class FooListView extends coconut.ui.View {
  @:attr var list:ListModel<Foo>;
  function render() '
    <div class="foo-list" style="background: blue">
      <for {i in list.items}>
        <Example2 model={i} />
      </for>
    </div>
  ';
}

class MyView extends View {
  function render() '
    <switch ${int()}>
      <case ${0}>
        <div>Zero</div>
      <case ${1}>
        <div>One</div>
      <case ${_}>
        <div>Default</div>
    </switch>
  ';

  function int() return 1;
}

class Issue19 extends View {
  @:optional @:attribute var foo:String;
  function render() '<div />';
  static function check() '<Issue19/>';
}


class Wrapper extends View {

  @:state var key:Int = 0;
  @:attribute var depth:Int;

	function render() '
    <if {depth == 0}>
      <div key=${key} onclick=${key++}>Key: $key</div>
    <else>
      <Wrapper depth={depth - 1} />
    </if>
  ';
}

class Btn extends View {
  @:attribute function onclick();
  @:ref var dom:js.html.Element;
  var count = 0;
  function render() '
    <button ref={dom} onclick=${onclick}>Rendered ${count++}</button>
  ';

  function viewDidMount()
    if (dom.nodeName != 'BUTTON') throw 'assert';
}

class Inst extends View {

  @:state public var count:Int = 0;

  var elt =
    #if react
      null;
    #else {
      var div = document.createDivElement();
      div.className = 'native-element';
      div.innerHTML = 'I am native!';
      div;
    }
    #end

  function render() '
    <div class="inst">
      Inst: ${elt}
      <button onclick=${count++}>$count</button>
    </div>
  ';

  override function viewDidMount()
    Tests.log('mounted');

  override function viewWillUnmount()
    Tests.log('unmounting');

}

class Outer extends View {
  @:attribute var children:Children;
  function render() {
    Tests.log('render');
    return @hxx '<div data-id={viewId}>Outer: {...children} <Inner>{...children}</Inner></div>';
  }
  override function viewDidUpdate()
    Tests.log('updated');
}


class Inner extends View {
  @:children var content:Children;
  function render() {
    Tests.log('render');
    return @hxx '<div data-id={viewId}>Inner: {...content}</div>';
  }

  override function viewDidUpdate()
    Tests.log('updated');
}

class DidRender extends View {
  @:attribute var counter:Int;
  function render() '
    <div>${counter}</div>
  ';

  override function viewDidRender(firstTime:Bool) {
    Tests.log('$firstTime');
  }

}

class Blargh extends View {
  @:attribute function blub(attr:{ foo:String }):Children;
  @:state public var hidden:Bool = false;
  function render() '
    <if {!hidden}>
      <>
        <div>1</div>
        <div>2</div>
        {...blub({ foo: "yeah" })}
        <button class="hide-blargh" onclick={hidden = true}>Hide</button>
      </>
    </if>
  ';
}

typedef Rec = Record<{ foo: Int, bar:Int }>;